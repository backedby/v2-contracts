// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IGasPriceOracle {
    function addResponse(uint256 price) external;
    function totalResponses() external view returns (uint256);
    function lastResponse() external view returns (uint256, uint256);
    function getResponse(uint256 index) external view returns (uint256, uint256);
}