// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "@backedby/v1-contracts/contracts/interfaces/IBBProfiles.sol";
import "@backedby/v1-contracts/contracts/interfaces/IBBTiers.sol";
import "@backedby/v1-contracts/contracts/interfaces/IBBSubscriptionsFactory.sol";
import "@backedby/v1-contracts/contracts/BBErrorsV01.sol";

import "../interfaces/IBBCashierRouter.sol";
import "../interfaces/IBBCashier.sol";
import "../interfaces/IBB721.sol";
import "../interfaces/IBB1155.sol";

contract CashierV01 is IBBCashier {
    struct Store {
        uint256 priceTierSetId;
        mapping(uint256 => uint256) prices;
        mapping(uint256 => Discount) discounts;
        mapping(uint256 => Refund) refunds;
        uint256 totalRefunds;
        bool paused;
        string cid;
    }

    struct Discount {
        // 0 - None, 1 - Percentage, 2 - Flat discount
        uint256 discountType;
        uint256 value;
    }

    struct Refund {
        uint256 tokenId;
        uint256 amount;
        uint256 value;
        address currency;
        uint256 requestedTimestamp;
        address requestor;
    }

    struct InitializeData {
        uint256 priceTierSetId;
        uint256[] priceTokenIds;
        uint256[] priceTierIds;
        uint256[] discountTierIds; 
        uint256[] discountTypes;
        uint256[] discountValues;
        bool paused;
        string cid;
    }

    struct Buy721Data {
        uint256 tierId;
        uint256[] itemIds;
    }

    struct Buy1155Data {
        uint256 tierId;
        uint256[] itemIds;
        uint256[] itemAmounts;
    }

    mapping(uint256 => Store) internal _stores;

    IBBProfiles internal immutable _bbProfiles;
    IBBTiers internal immutable _bbTiers;
    IBBSubscriptionsFactory internal immutable _bbSubscriptionsFactory;
    IBBCashierRouter internal immutable _bbCashierRouter;

    constructor(address bbProfiles, address bbTiers, address bbSubscriptionsFactory, address bbCashierRouter) {
        _bbProfiles = IBBProfiles(bbProfiles);
        _bbTiers = IBBTiers(bbTiers);
        _bbSubscriptionsFactory = IBBSubscriptionsFactory(bbSubscriptionsFactory);
        _bbCashierRouter = IBBCashierRouter(bbCashierRouter);
    }

    function initialize(uint256 storeId, bytes memory cashierData) external override {
        require(msg.sender == address(_bbCashierRouter));
        (InitializeData memory data) = abi.decode(cashierData, (InitializeData));

        _stores[storeId].priceTierSetId = data.priceTierSetId;
        for(uint256 i; i < data.priceTokenIds.length; i++) {
            _stores[storeId].prices[data.priceTokenIds[i]] = data.priceTierIds[i];
        }

        for(uint256 i; i < data.discountTierIds.length; i++) {
            if(data.discountTypes[i] == 1) {
                // Check percentage overflow
                require(data.discountValues[i] <= 100);
            }
            
            _stores[storeId].discounts[data.discountTierIds[i]] = Discount(data.discountTypes[i], data.discountValues[i]);
        }

        _stores[storeId].paused = data.paused;
        _stores[storeId].cid = data.cid;
    }

    function buy(address buyer, uint256 storeId, uint256 expectedPrice, address currency, bytes memory data) external override returns (bytes memory) {
        require(msg.sender == address(_bbCashierRouter));
        (uint256 buyType, bytes memory buyData) = abi.decode(data, (uint256, bytes));

        (,,address nft,) = _bbCashierRouter.getStore(storeId);
        if(buyType == 721) {
            Buy721Data memory buyParams = abi.decode(buyData, (Buy721Data));
            require(_get721Cost(storeId, currency, buyParams) >= expectedPrice);
            for(uint256 i; i < buyParams.itemIds.length; i++) {
                IBB721(nft).mint(buyer, buyParams.itemIds[i]);
            } 
        } else if(buyType == 1155) {
            Buy1155Data memory buyParams = abi.decode(buyData, (Buy1155Data));
            require(_get1155Cost(storeId, currency, buyParams) >= expectedPrice);
            for(uint256 i; i < buyParams.itemIds.length; i++) {
                IBB1155(nft).mint(buyer, buyParams.itemIds[i], buyParams.itemAmounts[i]);
            } 
        }

        return "";
    }

    function requestRefund(uint256 storeId, uint256 tokenId, uint256 amount, uint256 value, address currency) external returns (uint256) {
        (,,address nft,) = _bbCashierRouter.getStore(storeId);
        IERC165 erc165 = IERC165(nft);
        if(erc165.supportsInterface(type(IERC721).interfaceId)) {
            IERC721 nft721 = IERC721(nft);
            require(nft721.ownerOf(tokenId) == msg.sender);
            require(nft721.getApproved(tokenId) == address(this));
            
        } else if(erc165.supportsInterface(type(IERC1155).interfaceId)) {
            IERC1155 nft1155 = IERC1155(nft);
            require(nft1155.balanceOf(msg.sender, tokenId) >= amount);
            require(nft1155.isApprovedForAll(msg.sender, address(this)));
        }
        
        _stores[storeId].refunds[_stores[storeId].totalRefunds] = Refund(tokenId, amount, value, currency, block.timestamp, msg.sender);
        _stores[storeId].totalRefunds++;

        return _stores[storeId].totalRefunds - 1;
    }

    function getRefund(uint256 storeId, uint256 refundId) external view returns (uint256, uint256, uint256, uint256, address) {
        return (_stores[storeId].refunds[refundId].tokenId, _stores[storeId].refunds[refundId].amount, _stores[storeId].refunds[refundId].value, _stores[storeId].refunds[refundId].requestedTimestamp, _stores[storeId].refunds[refundId].requestor);
    }

    function cancelRefund(uint256 storeId, uint256 refundId) external {
        _stores[storeId].refunds[refundId].requestor = address(0);
    }

    function settleRefund(uint256 storeId, uint256 refundId, address refunder, address nftReceiver) external {
        require(_stores[storeId].refunds[refundId].requestor != address(0));
        (uint256 profileId,,,) = _bbCashierRouter.getStore(storeId);
        (address owner,,) = _bbProfiles.getProfile(profileId);
        require(msg.sender == owner);

        if(refunder != address(0)) {
            (,,address nft,) = _bbCashierRouter.getStore(storeId);
            IERC165 erc165 = IERC165(nft);
            if(erc165.supportsInterface(type(IERC721).interfaceId)) {
                IERC721(nft).safeTransferFrom(_stores[storeId].refunds[refundId].requestor, nftReceiver, _stores[storeId].refunds[refundId].tokenId, "");
            } else if(erc165.supportsInterface(type(IERC1155).interfaceId)) {
                IERC1155(nft).safeTransferFrom(_stores[storeId].refunds[refundId].requestor, nftReceiver, _stores[storeId].refunds[refundId].tokenId, _stores[storeId].refunds[refundId].amount, "");
            }

            IERC20(refunder).transferFrom(refunder, _stores[storeId].refunds[refundId].requestor, _stores[storeId].refunds[refundId].value);
        }

        _stores[storeId].refunds[refundId].requestor = address(0);
    }

    function _get1155Cost(uint256 storeId, address currency, Buy1155Data memory data) internal view returns (uint256 cost) {
        (uint256 profileId,,,) = _bbCashierRouter.getStore(storeId);

        for(uint256 i; i < data.itemIds.length; i++) {
            (,uint256 price, bool deprecated) = _bbTiers.getTier(profileId, _stores[storeId].priceTierSetId, _stores[storeId].prices[data.itemIds[i]], currency);
            require(deprecated == false);

            if(_stores[storeId].discounts[data.tierId].discountType == 0) {
                // No discount
                cost += price * data.itemAmounts[i];
            } else if(_stores[storeId].discounts[data.tierId].discountType == 1) {
                // Percentage discount
                cost += ((price * data.itemAmounts[i]) * (100 - _stores[storeId].discounts[data.tierId].value) / 100);
            } else if(_stores[storeId].discounts[data.tierId].discountType == 2) {
                // Flat discount
                if(_stores[storeId].discounts[data.tierId].value < price) {
                    cost += (price - _stores[storeId].discounts[data.tierId].value) * data.itemAmounts[i];
                }
            }
        }

        return cost;
    }

    function _get721Cost(uint256 storeId, address currency, Buy721Data memory data) internal view returns (uint256 cost) {
        (uint256 profileId,,,) = _bbCashierRouter.getStore(storeId);

        for(uint256 i; i < data.itemIds.length; i++) {
            (,uint256 price, bool deprecated) = _bbTiers.getTier(profileId, _stores[storeId].priceTierSetId, _stores[storeId].prices[data.itemIds[i]], currency);
            require(deprecated == false);

            if(_stores[storeId].discounts[data.tierId].discountType == 0) {
                // No discount
                cost += price;
            } else if(_stores[storeId].discounts[data.tierId].discountType == 1) {
                // Percentage discount
                cost += (price * (100 - _stores[storeId].discounts[data.tierId].value) / 100);
            } else if(_stores[storeId].discounts[data.tierId].discountType == 2) {
                // Flat discount
                if(_stores[storeId].discounts[data.tierId].value < price) {
                    cost += price - _stores[storeId].discounts[data.tierId].value;
                }
            }           
        }
    
        return cost;
    }   
}