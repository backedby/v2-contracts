// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "@backedby/v1-contracts/contracts/interfaces/IBBProfiles.sol";
import "@backedby/v1-contracts/contracts/BBErrorsV01.sol";

import "../interfaces/IBBCashierRouter.sol";
import "../interfaces/IBBCashier.sol";

contract BBCashierRouter is IBBCashierRouter {
    struct Store {
        uint256 profileId;
        uint256 contribution;
        address nft;
        address cashier;
        string cid;
    }

    mapping(uint256 => Store) _stores;
    uint256 _totalStores;

    IBBProfiles internal immutable _bbProfiles;

    constructor(address bbProfiles) {
        _bbProfiles = IBBProfiles(bbProfiles);
    }

    /*
        @dev Reverts if msg.sender is not profile IDs owner
    */
    modifier onlyProfileOwner(uint256 profileId) {
        (address profileOwner,,) = _bbProfiles.getProfile(profileId);
        require(profileOwner == msg.sender, BBErrorCodesV01.NOT_OWNER);
        _;
    }

    function getStore(uint256 storeId) external view override returns (uint256, uint256, address, address) {
        return (_stores[storeId].profileId, _stores[storeId].contribution, _stores[storeId].nft, _stores[storeId].cashier);
    }

    function initializeCashier(address store, uint256 profileId, uint256 contribution, address cashier, bytes calldata cashierData, string memory cid) external override onlyProfileOwner(profileId) returns (uint256) {
        _stores[_totalStores] = Store(profileId, contribution, store, cashier, cid);
        _totalStores++;

        IBBCashier(cashier).initialize(_totalStores - 1, cashierData);

        return _totalStores - 1;
    }

    function reinitializeCashier(uint256 storeId, uint256 profileId, uint256 contribution, address cashier, bytes calldata cashierData, string memory cid) external override onlyProfileOwner(_stores[storeId].profileId) {
        _stores[storeId] = Store(profileId, contribution, _stores[storeId].nft, cashier, cid);

        IBBCashier(cashier).initialize(storeId, cashierData);
    }

    function setProfileId(uint256 storeId, uint256 newProfileId) external override onlyProfileOwner(_stores[storeId].profileId) {
        _stores[storeId].profileId = newProfileId;
    }

    function buy(uint256 storeId, uint256 expectedPrice, address currency, bytes memory buyData) external override returns (bytes memory) {
        /* 
            TODO: Need to think about expected behaviour here, should it expect buy() to revert, or return a bool
        */
        (bytes memory returnData) = IBBCashier(_stores[storeId].cashier).buy(msg.sender, storeId, expectedPrice, currency, buyData);

        (,address receiver,) = _bbProfiles.getProfile(_stores[storeId].profileId);

        _pay(msg.sender, receiver, expectedPrice, currency, _stores[storeId].contribution);

        return returnData;
    }

    function _pay(address spender, address receiver, uint256 amount, address currency, uint256 treasuryContribution) internal returns (bool) {
        IERC20 token = IERC20(currency);

        // Check that the contract has enough allowance to process this transfer
        if ((token.allowance(spender, address(this)) >= amount) && token.balanceOf(spender) >= amount) { 
            token.transferFrom(spender, address(this), amount);

            uint256 receiverAmount = (amount * (100 - treasuryContribution)) / 100;

            if(receiverAmount > 0) {
                token.transfer(receiver, receiverAmount);
            }

            // Payment processed
            return true;
        } 

        // Insufficient funds
        return false;
    }
}