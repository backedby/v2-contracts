// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import "../interfaces/IBBCashierRouter.sol";
import "../interfaces/IBB1155.sol";

contract BB1155 is IBB1155, ERC1155, Initializable {
    IBBCashierRouter internal _bbCashierRouter;

    uint256 internal _storeId;

    mapping(uint256 => uint256) internal _supplies;
    uint256 internal _totalSupply;
    
    mapping(uint256 => uint256) internal _maxSupplies;
    uint256 internal _defaultMaxSupply;

    mapping(uint256 => uint256) internal _maxBalances;
    uint256 internal _defaultMaxBalance;

    bool internal _soulbound;

    constructor() ERC1155("") {

    }

    function initialize(uint256 storeId, address cashierRouter, string memory uri, uint256 defaultMaxSupply, uint256[] memory maxSupplyIndexes, uint256[] memory maxSupplyValues, uint256 defaultMaxBalance, uint256[] memory maxBalanceIndexes, uint256[] memory maxBalanceValues, bool soulBound) external override initializer {
        _storeId = storeId;
        _bbCashierRouter = IBBCashierRouter(cashierRouter);

        _setURI(uri);
        
        _defaultMaxSupply = defaultMaxSupply;
        for(uint256 i; i < maxSupplyIndexes.length; i++) {
            _maxSupplies[maxSupplyIndexes[i]] = maxSupplyValues[i] + 1;
        }

        _defaultMaxBalance = defaultMaxBalance;
        for(uint256 i; i < maxBalanceIndexes.length; i++) {
            _maxBalances[maxBalanceIndexes[i]] = maxBalanceValues[i] + 1;
        }

        _soulbound = soulBound;
    }

    function mint(address to, uint256 tokenId, uint256 amount) external override {
        require(_totalSupply + amount <= _getMaxSupply(tokenId));

        (,,,address cashier) = _bbCashierRouter.getStore(_storeId);
        require(msg.sender == cashier);

        for(uint256 i; i < amount; i++) {
            _mint(to, tokenId, amount, "");
        }

        _supplies[tokenId] += amount;
        _totalSupply += amount;
    }

    function _beforeTokenTransfer(address /*operator*/, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory /*data*/) internal view override {
        for(uint256 i; i < ids.length; i++) {
            require(balanceOf(to, ids[i]) + amounts[i] <= _getMaxBalance(ids[i]));
        }

        if(_soulbound) {
            require(from == address(0) || to == address(0));
        }
    }

    function _getMaxSupply(uint256 tokenId) internal view returns (uint256) {
        if(_maxSupplies[tokenId] == 0) {
            return _defaultMaxSupply;
        }
        
        return _maxSupplies[tokenId] - 1;
    }

    function _getMaxBalance(uint256 tokenId) internal view returns (uint256) {
        if(_maxBalances[tokenId] == 0) {
            return _defaultMaxBalance;
        }

        return _maxBalances[tokenId] - 1;
    }
}