// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../interfaces/IGasPriceOracle.sol";

contract GasPriceOracle is IGasPriceOracle {
    struct Response {
        uint256 price;
        uint256 timestamp;
    }

    mapping(uint256 => Response) internal _responses;
    uint256 internal _totalResponses;

    address internal _node;

    constructor(address node) {
        _node = node;
    }

    function addResponse(uint256 price) external {
        require(msg.sender == _node);
        _responses[_totalResponses] = Response(price, block.timestamp);
        _totalResponses++;
    }

    function totalResponses() external view returns (uint256) {
        return _totalResponses;
    }

    function lastResponse() external view returns (uint256, uint256) {
        return (_responses[_totalResponses - 1].price, _responses[_totalResponses - 1].timestamp);
    }

    function getResponse(uint256 index) external view returns (uint256, uint256) {
        require(index < _totalResponses);
        return (_responses[index].price, _responses[index].timestamp);
    }
}