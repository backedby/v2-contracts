
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IBBCashierRouter {
    function getStore(uint256 storeId) external view returns (uint256 profileId, uint256 contribution, address nft, address cashier);
    function initializeCashier(address store, uint256 profileId, uint256 contribution, address cashier, bytes calldata cashierData, string memory cid) external returns (uint256 storeId);
    function reinitializeCashier(uint256 storeId, uint256 profileId, uint256 contribution, address cashier, bytes calldata cashierData, string memory cid) external;
    function setProfileId(uint256 storeId, uint256 newProfileId) external;
    function buy(uint256 storeId, uint256 expectedPrice, address currency, bytes memory buyData) external returns (bytes memory);
}