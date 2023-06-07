// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@backedby/v1-contracts/contracts/interfaces/IBBProfiles.sol";
import "@backedby/v1-contracts/contracts/interfaces/IBBTiers.sol";
import "@backedby/v1-contracts/contracts/interfaces/IBBSubscriptionsFactory.sol";

contract ProfileSetup {
    IBBProfiles public immutable BBProfiles;
    IBBTiers public immutable BBTiers;
    IBBSubscriptionsFactory public immutable BBSubscriptionsFactory;

    constructor(address profiles, address tiers, address subscriptionsFactory) {
        BBProfiles = IBBProfiles(profiles);
        BBTiers = IBBTiers(tiers);
        BBSubscriptionsFactory = IBBSubscriptionsFactory(subscriptionsFactory);
    }

    function setup(
        address owner, 
        address receiver, 
        string memory profileCid, 
        uint256[] memory tierPrices, 
        string[] memory tierCids, 
        bool[] memory tierDeprecations, 
        address[] memory tierCurrencies, 
        uint256[] memory tierMultipliers, 
        uint256 subscriptionContribution
    ) external {
        uint256 profileId = BBProfiles.createProfile(address(this), address(this), "");
        uint256 tierSetId = BBTiers.createTiers(profileId, tierPrices, tierCids, tierDeprecations, tierCurrencies, tierMultipliers);    
        BBSubscriptionsFactory.createSubscriptionProfile(profileId, tierSetId, subscriptionContribution);
        BBProfiles.editProfile(profileId, owner, receiver, profileCid);
    }
}