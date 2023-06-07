// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface ISubscriptionFeeOracle {
    function setSubscriptionFeeOwner(address owner) external;

    function calculateSubscriptionFee(address token, uint256 amount) external;
}