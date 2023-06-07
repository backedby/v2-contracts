// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@vittominacori/contracts/token/ERC1363/ERC1363.sol";
import "@cb-eip3309/contracts/lib/EIP3009.sol";
import "@cb-eip3309/contracts/lib/EIP2612.sol";

contract BBToken is ERC1363, EIP3009, EIP2612 {
    constructor() ERC20 ("BackedBy", "BB") {
        _mint(msg.sender, (10**18) * 100000000);
    }
}