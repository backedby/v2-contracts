// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IBB1155 {
    function initialize(uint256 storeId, address cashierRouter, string memory uri, uint256 defaultMaxSupply, uint256[] memory maxSupplyIndexes, uint256[] memory maxSupplyValues, uint256 defaultMaxBalance, uint256[] memory maxBalanceIndexes, uint256[] memory maxBalanceValues, bool soulBound) external;
    function mint(address to, uint256 tokenId, uint256 amount) external;
}