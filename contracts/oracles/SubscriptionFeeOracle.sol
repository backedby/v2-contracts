// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "@backedby/v1-contracts/contracts/interfaces/IBBSubscriptionsFactory.sol";

import "../interfaces/ISubscriptionFeeOracle.sol";

contract SubscriptionFeeOracle is ISubscriptionFeeOracle, Ownable {
    IBBSubscriptionsFactory public immutable BBSubscriptionsFactory;

    IERC20 internal _currency;

    constructor(address subscriptionsFactory, address owner) {
        BBSubscriptionsFactory = IBBSubscriptionsFactory(subscriptionsFactory);
        _transferOwnership(owner);
    }

    function setSubscriptionFeeOwner(address owner) external onlyOwner {
        BBSubscriptionsFactory.setSubscriptionFeeOwner(owner);
    } 

    function calculateSubscriptionFee(address token, uint256 amount) external {
        require(BBSubscriptionsFactory.isSubscriptionsDeployed(token));
        _currency = IERC20(token);

        uint256 startGas = gasleft();

        require(_currency.allowance(msg.sender, address(this)) >= amount);
        require(_currency.balanceOf(msg.sender) >= amount);

        _currency.transferFrom(msg.sender, address(this), amount);
        _currency.transfer(msg.sender, amount);

        // Gas used plus overhead for single performUpkeep
        uint256 gasUsed = (startGas - gasleft()) + 75000;

        // Multiply fee by five years (60 months) of upkeeps
        BBSubscriptionsFactory.setSubscriptionFee(token, gasUsed * 60);
    }
}