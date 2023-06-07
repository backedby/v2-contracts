// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./BBNFTProxy.sol";
import "../cashier/CashierV01.sol";
import "./BB721.sol";
import "./BB1155.sol";
import "../interfaces/IBBCashierRouter.sol";
import "../interfaces/IBB721.sol";
import "../interfaces/IBB1155.sol";

contract BBNFTFactory {
    struct BB721Data {
        string name;
        string symbol;
        string uri;
        uint256 maxSupply;
        uint256 maxBalance;
        bool soulBound;
    }

    struct BB1155Data {
        string uri;
        uint256 defaultMaxSupply;
        uint256[] maxSupplyIndexes;
        uint256[] maxSupplyValues;
        uint256 defaultMaxBalance;
        uint256[] maxBalanceIndexes;
        uint256[] maxBalanceValues;
        bool soulBound;
    }

    address internal immutable _bb721;
    address internal immutable _bb1155;

    address internal immutable _cashier;

    IBBCashierRouter internal immutable _bbCashierRouter;

    constructor(address bbProfiles, address bbTiers, address bbSubscriptionsFactory, address bbCashierRouter) {
        _bbCashierRouter = IBBCashierRouter(bbCashierRouter);

        _cashier = address(new CashierV01(bbProfiles, bbTiers, bbSubscriptionsFactory, bbCashierRouter));

        _bb721 = address(new BB721());
        _bb1155 = address(new BB1155());
    }

    function deployBB721(uint256 profileId, uint256 contribution, bytes memory cashierData, string memory cid, BB721Data memory bb721data) external {
        address store = address(new BBNFTProxy(_bb721));
        uint256 storeId = _bbCashierRouter.initializeCashier(store, profileId, contribution, _cashier, cashierData, cid);

        IBB721(store).initialize(
            storeId, 
            address(_bbCashierRouter), 
            bb721data.name, 
            bb721data.symbol, 
            bb721data.uri, 
            bb721data.maxSupply, 
            bb721data.maxBalance, 
            bb721data.soulBound
        );
    }

    function deployBB1155(uint256 profileId, uint256 contribution, bytes memory cashierData, string memory cid, BB1155Data memory bb1155data) external {
        address store = address(new BBNFTProxy(_bb1155));
        uint256 storeId = _bbCashierRouter.initializeCashier(store, profileId, contribution, _cashier, cashierData, cid);

        IBB1155(store).initialize(
            storeId, 
            address(_bbCashierRouter), 
            bb1155data.uri, 
            bb1155data.defaultMaxSupply, 
            bb1155data.maxSupplyIndexes, 
            bb1155data.maxSupplyValues, 
            bb1155data.defaultMaxBalance, 
            bb1155data.maxBalanceIndexes, 
            bb1155data.maxBalanceValues, 
            bb1155data.soulBound
        );
    }
}