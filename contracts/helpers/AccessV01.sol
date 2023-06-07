// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/AccessControl.sol";

import "@backedby/v1-contracts/contracts/interfaces/IBBProfiles.sol";
import "@backedby/v1-contracts/contracts/interfaces/IBBPosts.sol";
import "@backedby/v1-contracts/contracts/interfaces/IBBTiers.sol";
import "@backedby/v1-contracts/contracts/interfaces/IBBSubscriptionsFactory.sol";
import "@backedby/v1-contracts/contracts/interfaces/IBBPermissionsV01.sol";

contract AccessV01 is AccessControl, IBBPermissionsV01 {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant CONTENT_ROLE = keccak256("CONTENT_ROLE");

    IBBProfiles public immutable BBProfiles;
    IBBPosts public immutable BBPosts;
    IBBTiers public immutable BBTiers;
    IBBSubscriptionsFactory public immutable BBSubscriptionsFactory;

    mapping (address => bool) internal _subscriptionViewers;

    constructor(address admin, address profiles, address posts, address tiers, address subscriptionsFactory) {
        BBProfiles = IBBProfiles(profiles);
        BBPosts = IBBPosts(posts);
        BBTiers = IBBTiers(tiers);
        BBSubscriptionsFactory = IBBSubscriptionsFactory(subscriptionsFactory);
        
        // Allows role granting and revoking
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(CONTENT_ROLE, admin);
    }

    // BBProfiles
    function editProfile(uint256 profileId, address owner, address receiver, string calldata cid) external onlyRole(ADMIN_ROLE) {
        BBProfiles.editProfile(profileId, owner, receiver, cid);
    }

    // BBPosts
    function createPost(uint256 profileId, string calldata cid) external onlyRole(CONTENT_ROLE) returns (uint256) {
        return BBPosts.createPost(profileId, cid);
    }
    function editPost(uint256 profileId, uint256 postId, string calldata cid) external onlyRole(CONTENT_ROLE) {
        BBPosts.editPost(profileId, postId, cid);
    }

    // BBTiers
    function createTiers(uint256 profileId, uint256[] calldata prices, string[] calldata cids, bool[] memory deprecated, address[] calldata supportedCurrencies, uint256[] calldata priceMultipliers) external onlyRole(ADMIN_ROLE) returns (uint256) {
        return BBTiers.createTiers(profileId, prices, cids, deprecated, supportedCurrencies, priceMultipliers);
    }
    function editTiers(uint256 profileId, uint256 tierSetId, uint256[] calldata prices, string[] calldata cids, bool[] memory deprecated) external onlyRole(ADMIN_ROLE) {
        BBTiers.editTiers(profileId, tierSetId, prices, cids, deprecated);
    }
    function setSupportedCurrencies(uint256 profileId, uint256 tierSetId, address[] calldata supportedCurrencies, uint256[] calldata priceMultipliers) external onlyRole(ADMIN_ROLE) {
        BBTiers.setSupportedCurrencies(profileId, tierSetId, supportedCurrencies, priceMultipliers);
    }

    // BBSubscriptionFactory
    function createSubscriptionProfile(uint256 profileId, uint256 tierSetId, uint256 contribution) external onlyRole(ADMIN_ROLE) {
        BBSubscriptionsFactory.createSubscriptionProfile(profileId, tierSetId, contribution);
    }
    function setContribution(uint256 profileId, uint256 contribution) external onlyRole(ADMIN_ROLE) {
        BBSubscriptionsFactory.setContribution(profileId, contribution);
    }

    // IBBPermissionsV01
    function canViewSubscription(address account) external view returns(bool) {
        return _subscriptionViewers[account];
    }
    function setViewSubscription(address account, bool state) external onlyRole(ADMIN_ROLE) {
        _subscriptionViewers[account] = state;
    }
}