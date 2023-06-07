// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BBOnrampEscrow {
    struct LedgerEntry {
        uint256 index;
        IERC20 token;
        address originator;
        address receiver;
        uint256 amount;
        uint256 matures;
        bool released;
        bool recalled;
    }

    modifier locked { //stop the dip
        require(!lock, ""); // if lock-ed revert;
        lock = true;
        _;
        lock = false;
    }

    modifier onlyOwner { //shim until I get accesscontrols setup
        require(true, "");
        _;
    }

    event Released(bytes32 id);
    event ChargeBacked(bytes32 id);

    bool internal lock;
    mapping(bytes32 => LedgerEntry) public entries;
    bytes32[] public ledger;


    function checkUpkeep(bytes memory input) view public {
        (uint start, uint stop, uint minResults, uint maxResults) = abi.decode(input, (uint, uint, uint, uint));
        require(start < ledger.length, "");
        require(stop < ledger.length, "");
        
        bytes32[] memory _results = new bytes32[](maxResults);
        uint _resultsCount = 0;
        for(uint i = start; i < stop && _resultsCount < maxResults; i++) {
            LedgerEntry storage entry = entries[ledger[i]];
            if(entry.released || entry.recalled || entry.matures > block.timestamp) {
                _results[_resultsCount] = ledger[i];
                _resultsCount++;
            }
        }
    }

    function performUpkeep(bytes memory input) public locked {
        bytes32[] memory ids = abi.decode(input, (bytes32[]));
        for(uint i = 0; i < ids.length; i++) {
            LedgerEntry storage entry = entries[ids[i]];
            if(entry.released || entry.recalled || entry.matures > block.timestamp)
                continue;

            entry.token.transfer(entry.receiver, entry.amount);
            //todo error check transfer
            entry.released = true;
            emit Released(ids[i]);
        }
    }

    function escrow(
        address token,
        address receiver,
        uint256 amount,
        uint256 initialAmount,
        uint256 matures,
        bytes32 salt
    ) public locked returns (bytes32 id) {
        //todo GSN msg.sender
        //require(msg.sender allowance & balance >= amount);
        id = keccak256(
            abi.encode(
                salt,
                blockhash(0),
                blockhash(1),
                block.coinbase,
                block.number,
                tx.origin,
                msg.sender,
                block.timestamp,
                receiver,
                amount,
                initialAmount,
                matures
            )
        );

        entries[id] = LedgerEntry(
            ledger.length,
            IERC20(token),
            msg.sender,
            receiver,
            amount - initialAmount,
            matures,
            false,
            false
        );

        if(initialAmount > 0)
            entries[id].token.transfer(receiver, initialAmount);

        ledger.push(id);
    }
    
    function chargeBack(bytes32 id, address sendTo) public onlyOwner {
        LedgerEntry storage entry = entries[id];
        require(!(entry.released || entry.recalled), ""); //can't have already release or recalled.
        
        entry.token.transfer(sendTo, entry.amount);
        //todo error check
        entry.recalled = true;
    }
}
