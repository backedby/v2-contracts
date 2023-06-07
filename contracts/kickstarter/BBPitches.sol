// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "@backedby/v1-contracts/contracts/interfaces/IBBTiers.sol";
import "@backedby/v1-contracts/contracts/interfaces/IBBProfiles.sol";

import "@backedby/v1-contracts/contracts/BBErrorsV01.sol";

import "../interfaces/IBBPitches.sol";

contract BBPitches is IBBPitches {
    struct Pitch {
        mapping(address => uint256) balances;
        uint256 balance;
        uint256 goal;
        uint256 expiration;
        address receiver;
        uint256 tierSetId;
        uint256 contribution;
        string cid;
    }

    struct Funder {
        uint256 balance;
        uint256[] tierIds;
        mapping(uint256 => uint256) tierAmounts;
    }

    mapping(uint256 => mapping(uint256 => Pitch)) _pitches;
    mapping(uint256 => uint256) _totalPitches;

    //Profile ID => Pitch ID => Currency => Wallet => Balance
    mapping(uint256 => mapping(uint256 => mapping(address => mapping(address => Funder)))) _funders;

    IBBProfiles internal immutable _bbProfiles;
    IBBTiers internal immutable _bbTiers;

    address internal _treasury;
    address internal _treasuryOwner;

    constructor(address bbProfiles, address bbTiers, address treasury, address treasuryOwner) {
        _bbProfiles = IBBProfiles(bbProfiles);
        _bbTiers = IBBTiers(bbTiers);

        _treasury = treasury;
        _treasuryOwner = treasuryOwner;
    }

    /*
        @dev Reverts if msg.sender is not profile IDs owner
    */
    modifier onlyProfileOwner(uint256 profileId) {
        (address profileOwner,,) = _bbProfiles.getProfile(profileId);
        require(profileOwner == msg.sender, BBErrorCodesV01.NOT_OWNER);
        _;
    }

    /*
        @dev Reverts if tier set ID does not exist
    */
    modifier tierSetExists(uint256 profileId, uint256 tierSetId) {
        require(profileId < _bbProfiles.totalProfiles(), BBErrorCodesV01.PROFILE_NOT_EXIST);
        require(tierSetId < _bbTiers.totalTierSets(profileId), BBErrorCodesV01.TIER_SET_NOT_EXIST);
        _;
    }

    /*
        @dev Reverts if tier ID does not exist
    */
    modifier tierExists(uint256 profileId, uint256 tierSetId, uint256 tierId) {
        require(profileId < _bbProfiles.totalProfiles(), BBErrorCodesV01.PROFILE_NOT_EXIST);
        require(tierSetId < _bbTiers.totalTierSets(profileId), BBErrorCodesV01.TIER_SET_NOT_EXIST);
        require(tierId < _bbTiers.totalTiers(profileId, tierSetId), BBErrorCodesV01.TIER_NOT_EXIST);
        _;
    }

    /*
        TODO: Comments
    */
    modifier pitchExists(uint256 profileId, uint256 pitchId) {
        require(profileId < _bbProfiles.totalProfiles(), BBErrorCodesV01.PROFILE_NOT_EXIST);
        require(pitchId < _totalPitches[profileId]);
        _;
    }

    /*
        @dev Reverts if msg.sender is not treasury owner
    */
    modifier onlyTreasuryOwner {
        require(msg.sender == _treasuryOwner, BBErrorCodesV01.NOT_OWNER);
        _;
    }

    function createPitch(uint256 profileId, uint256 goal, uint256 expiration, address receiver, uint256 tierSetId, uint256 contribution, string memory cid) external override onlyProfileOwner(profileId) tierSetExists(profileId, tierSetId) {
        require(contribution >= 1);
        require(contribution <= 100);
        require(goal > 0);

        _pitches[profileId][_totalPitches[profileId]].goal = goal;
        _pitches[profileId][_totalPitches[profileId]].expiration = expiration;
        _pitches[profileId][_totalPitches[profileId]].receiver = receiver;
        _pitches[profileId][_totalPitches[profileId]].tierSetId = tierSetId;
        _pitches[profileId][_totalPitches[profileId]].contribution = contribution;
        _pitches[profileId][_totalPitches[profileId]].cid = cid;

        _totalPitches[profileId]++;
    }

    function endPitch(uint256 profileId, uint256 pitchId) external onlyProfileOwner(profileId) pitchExists(profileId, pitchId) {
        require(block.timestamp < _pitches[profileId][pitchId].expiration);

        _pitches[profileId][pitchId].balance = 0;
        _pitches[profileId][pitchId].expiration = 0;
    }

    function claimPitchFunds(uint256 profileId, uint256 pitchId, address currency) external override pitchExists(profileId, pitchId) {
        require(block.timestamp >= _pitches[profileId][pitchId].expiration);
        require(_pitches[profileId][pitchId].balance >= _pitches[profileId][pitchId].goal);
        require(_pitches[profileId][pitchId].balances[currency] > 0);

        uint256 receiverAmount = (_pitches[profileId][pitchId].balances[currency] * (100 - _pitches[profileId][pitchId].contribution)) / 100;
        uint256 contributionAmount = _pitches[profileId][pitchId].balances[currency] - receiverAmount;

        IERC20 token = IERC20(currency);

        token.transfer(_pitches[profileId][pitchId].receiver, receiverAmount);
        token.transfer(_treasury, contributionAmount);

        _pitches[profileId][pitchId].balances[currency] = 0;
    }

    function fundPitch(uint256 profileId, uint256 pitchId, uint256 tierId, address currency, uint256 amount) external override pitchExists(profileId, pitchId) tierExists(profileId, _pitches[profileId][pitchId].tierSetId, tierId) {
        require(block.timestamp < _pitches[profileId][pitchId].expiration);

        uint256 tierSetId = _pitches[profileId][pitchId].tierSetId;
        require(_bbTiers.isCurrencySupported(profileId, tierSetId, currency));

        (,uint256 tierPrice,) = _bbTiers.getTier(profileId, tierSetId, tierId, currency);
        require(amount >= tierPrice);
        IERC20(currency).transferFrom(msg.sender, address(this), amount);

        _funders[profileId][pitchId][currency][msg.sender].balance += amount;
        _funders[profileId][pitchId][currency][msg.sender].tierAmounts[tierId]++;

        if(_funders[profileId][pitchId][currency][msg.sender].tierAmounts[tierId] == 0) {
            _funders[profileId][pitchId][currency][msg.sender].tierIds.push(tierId);
        }

        // TODO: Am I retarded ???
        _pitches[profileId][pitchId].balances[currency] += amount;
        _pitches[profileId][pitchId].balance += amount * _bbTiers.getCurrencyMultiplier(profileId, tierSetId, currency);
    }

    function withdrawFunding(uint256 profileId, uint256 pitchId, address currency) external override pitchExists(profileId, pitchId) {
        if(_pitches[profileId][pitchId].balance >= _pitches[profileId][pitchId].goal) {
            require(block.timestamp >= _pitches[profileId][pitchId].expiration);      
        } else {    
            require(block.timestamp < _pitches[profileId][pitchId].expiration);      
        }
        
        IERC20(currency).transfer(msg.sender, _funders[profileId][pitchId][currency][msg.sender].balance);

        for(uint256 i = 0; i < _funders[profileId][pitchId][currency][msg.sender].tierIds.length; i++) {
            _funders[profileId][pitchId][currency][msg.sender].tierAmounts[_funders[profileId][pitchId][currency][msg.sender].tierIds[i]] = 0;
        }
        _funders[profileId][pitchId][currency][msg.sender].tierIds = new uint256[](0);
        _funders[profileId][pitchId][currency][msg.sender].balance = 0;
    }

    /*
        @notice Sets the treasury owner
        @param Treasury owner address
    */
    function setTreasuryOwner(address account) external onlyTreasuryOwner {
        _treasuryOwner = account;
    }

        /*
        @notice Get the treasury owner
        @return Treasury address
    */
    function getTreasuryOwner() external view returns (address) {
        return _treasuryOwner;
    }

        /*
        @notice Set the treasury address
        @param Treasury address
    */
    function setTreasury(address account) external onlyTreasuryOwner {
        _treasury = account;
    }

    /*
        @notice Get the treasury address
        @return Treasury address
    */
    function getTreasury() external view returns (address treasury) {
        return _treasury;
    }
}