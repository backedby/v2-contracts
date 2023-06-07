// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IBBMessages {
    function setMessage(uint256 profileId, uint256 postId, uint256 tierSetId, string memory cid, uint256 contribution) external;

    function buyMessage(uint256 profileId, uint256 postId, uint256 tierId, address currency) external;

    function hasMessageAccess(uint256 profileId, uint256 postId, uint256 tierId, address account) external view returns (bool);
}