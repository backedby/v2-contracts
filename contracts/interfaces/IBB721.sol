// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IBB721 {
    function initialize(uint256 storeId, address cashierRouter, string memory name, string memory symbol, string memory uri, uint256 maxSupply, uint256 maxBalance, bool soulBound) external;
    function mint(address to, uint256 tokenId) external;
}