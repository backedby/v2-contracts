// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "@backedby/v1-contracts/contracts/interfaces/IBBSubscriptionsFactory.sol";
import "@backedby/v1-contracts/contracts/interfaces/IBBPosts.sol";
import "@backedby/v1-contracts/contracts/interfaces/IBBProfiles.sol";
import "@backedby/v1-contracts/contracts/interfaces/IBBTiers.sol";

import "@backedby/v1-contracts/contracts/BBErrorsV01.sol";

import "../interfaces/IBBMessages.sol";

contract BBMessages is IBBMessages {
    struct Message {
        uint256 tierSetId;
        string cid;
        uint256 contribution;
    }

    mapping(uint256 => mapping(uint256 => Message)) internal _messages;
    mapping(uint256 => uint256) internal _totalMessages;

    // Profile ID => Post ID => Tier ID => Account => Access
    mapping(uint256 => mapping(uint256 => mapping(uint256 => mapping(address => bool)))) internal _access;

    IBBProfiles internal immutable _bbProfiles;
    IBBPosts internal immutable _bbPosts;
    IBBTiers internal immutable _bbTiers;

    address internal _treasuryOwner;
    address internal _treasury;

    constructor(address bbProfiles, address bbPosts, address bbTiers) {
        _bbProfiles = IBBProfiles(bbProfiles);
        _bbPosts = IBBPosts(bbPosts);
        _bbTiers = IBBTiers(bbTiers);
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
        @dev Reverts if post ID does not exist

        @param Profile ID
        @param Post ID
    */
    modifier postExists(uint256 profileId, uint256 postId) {
        require(postId < _bbPosts.profilesTotalPosts(profileId), BBErrorCodesV01.POST_NOT_EXIST);
        _;
    }

    function setTreasuryOwner(address account) external {

    }

    function getTreasuryOwner() external view returns (address treasury) {

    }

    function setTreasury(address account) external {

    }

    function getTreasury() external view returns (address treasury) {

    }

    function setMessage(uint256 profileId, uint256 postId, uint256 tierSetId, string memory cid, uint256 contribution) external override onlyProfileOwner(profileId) {      
        _messages[profileId][postId].tierSetId = tierSetId;
        _messages[profileId][postId].cid = cid;
        _messages[profileId][postId].contribution = contribution;
    }

    function buyMessage(uint256 profileId, uint256 postId, uint256 tierId, address currency) external override postExists(profileId, postId) {
        (,uint256 price,) = _bbTiers.getTier(profileId, _messages[profileId][postId].tierSetId, tierId, currency);
        
        IERC20 token = IERC20(currency);

        uint256 receiverAmount = (price * (100 - _messages[profileId][postId].contribution)) / 100;
        (,address receiver,) = _bbProfiles.getProfile(profileId);
        token.transferFrom(msg.sender, receiver, receiverAmount);

        uint256 treasuryAmount = price - receiverAmount;
        token.transferFrom(msg.sender, _treasury, treasuryAmount);

        _access[profileId][postId][tierId][msg.sender] = true;
    }

    function hasMessageAccess(uint256 profileId, uint256 postId, uint256 tierId, address account) external view override returns (bool) {
        (address profileOwner,,) = _bbProfiles.getProfile(profileId);

        // Profile owner always has accesss
        if(profileOwner == account) {
            return true;
        }

        return _access[profileId][postId][tierId][msg.sender];
    }
}