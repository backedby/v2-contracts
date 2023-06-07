// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IBBCashier {
    function initialize(uint256 storeId, bytes memory cashierData) external;
    function buy(address buyer, uint256 storeId, uint256 expectedPrice, address currency, bytes memory buyData) external returns (bytes memory);
}