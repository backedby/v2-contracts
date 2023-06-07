// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IBBPitches {
    function createPitch(uint256 profileId, uint256 goal, uint256 expiration, address receiver, uint256 tierSetId, uint256 contribution, string memory cid) external;
    function endPitch(uint256 profileId, uint256 pitchId) external;
    function claimPitchFunds(uint256 profileId, uint256 pitchId, address currency) external;

    function fundPitch(uint256 profileId, uint256 pitchId, uint256 tierId, address currency, uint256 amount) external;
    function withdrawFunding(uint256 profileId, uint256 pitchId, address currency) external;
}