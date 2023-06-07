// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/governance/Governor.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";

import "@backedby/v1-contracts/contracts/interfaces/IBBSubscriptionsFactory.sol";

import "../interfaces/ISubscriptionFeeOracle.sol";

contract BBGovernanceV01 is Governor, GovernorSettings, GovernorCountingSimple, GovernorVotes, GovernorVotesQuorumFraction, GovernorTimelockControl {
    
    IBBSubscriptionsFactory immutable public BBSubscriptionsFactory;

    ISubscriptionFeeOracle public SubscriptionFeeOracle;

    constructor(IVotes token, TimelockController timelock, address subscriptionsFactory, address subscriptionFeeOracle) 
    Governor("BBGovernanceV01") 
    GovernorSettings(1, 50400, 10**18) 
    GovernorVotes(token) 
    GovernorVotesQuorumFraction(15) 
    GovernorTimelockControl(timelock) {
        BBSubscriptionsFactory = IBBSubscriptionsFactory(subscriptionsFactory);
        SubscriptionFeeOracle = ISubscriptionFeeOracle(subscriptionFeeOracle);
    }

    // The following functions are overrides required by Solidity.

    function votingDelay() public view override(IGovernor, GovernorSettings) returns (uint256) {
        return super.votingDelay();
    }

    function votingPeriod() public view override(IGovernor, GovernorSettings) returns (uint256) {
        return super.votingPeriod();
    }

    function quorum(uint256 blockNumber) public view override(IGovernor, GovernorVotesQuorumFraction) returns (uint256) {
        return super.quorum(blockNumber);
    }

    function state(uint256 proposalId) public view override(Governor, GovernorTimelockControl) returns (ProposalState) {
        return super.state(proposalId);
    }

    function propose(address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description) public override(Governor, IGovernor) returns (uint256) {
        return super.propose(targets, values, calldatas, description);
    }

    function proposalThreshold() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.proposalThreshold();
    }

    function _execute(uint256 /*proposalId*/, address[] memory /*targets*/, uint256[] memory /*values*/, bytes[] memory calldatas, bytes32 /*descriptionHash*/) internal override(Governor, GovernorTimelockControl) {
        for(uint256 i; i < calldatas.length; i++) {
            (uint256 id, bytes memory data) = abi.decode(calldatas[i], (uint256, bytes));

            if(id == 0) {
                // Set treasury owner
                address treasuryOwner = abi.decode(data, (address));
                BBSubscriptionsFactory.setTreasuryOwner(treasuryOwner);
            } else if (id == 1) {
                // Set treasury
                address treasury = abi.decode(data, (address));
                BBSubscriptionsFactory.setTreasury(treasury);
            } else if (id == 2) {
                // Set gas oracle owner
                address gasOracleOwner = abi.decode(data, (address));
                BBSubscriptionsFactory.setGasOracleOwner(gasOracleOwner);
            } else if (id == 3) {
                // Set gas oracle
                address gasOracle = abi.decode(data, (address));
                BBSubscriptionsFactory.setGasOracle(gasOracle);
            } else if (id == 4) {
                // Set subscription fee owner
                address subscriptionFeeOwner = abi.decode(data, (address));
                SubscriptionFeeOracle.setSubscriptionFeeOwner(subscriptionFeeOwner);
                SubscriptionFeeOracle = ISubscriptionFeeOracle(subscriptionFeeOwner);
            } else {
                revert();
            }
        }
    }

    function _cancel(address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash) internal override(Governor, GovernorTimelockControl) returns (uint256) {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    function _executor() internal view override(Governor, GovernorTimelockControl) returns (address) {
        return super._executor();
    }

    function supportsInterface(bytes4 interfaceId) public view override(Governor, GovernorTimelockControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}