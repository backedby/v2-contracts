// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import "../interfaces/IBBCashierRouter.sol";
import "../interfaces/IBB721.sol";

contract BB721 is IBB721, ERC721, Initializable {
    IBBCashierRouter internal _bbCashierRouter;

    uint256 internal _storeId;

    uint256 internal _totalSupply;
    uint256 internal _maxSupply;

    uint256 internal _maxBalance;

    bool internal _soulbound;

    string internal _name;
    string internal _symbol;
    string internal _uri;

    constructor() ERC721("", "") {

    }

    function name() public view override returns (string memory) {
        return _name;
    }

    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    function _baseURI() internal view override returns (string memory) {
        return _uri;
    }

    function initialize(uint256 storeId, address cashierRouter, string memory tokenName, string memory tokenSymbol, string memory uri, uint256 maxSupply, uint256 maxBalance, bool soulBound) external override initializer {
        _storeId = storeId;
        _bbCashierRouter = IBBCashierRouter(cashierRouter);
        
        _name = tokenName;
        _symbol = tokenSymbol;
        _uri = uri;
        _maxSupply = maxSupply;
        _maxBalance = maxBalance;
        _soulbound = soulBound;
    }

    function mint(address to, uint256 tokenId) external override {
        require(tokenId < _maxSupply);

        (,,,address cashier) = _bbCashierRouter.getStore(_storeId);
        require(msg.sender == cashier);

        _safeMint(to, tokenId);

        _totalSupply++;
    }

    function _beforeTokenTransfer(address from, address to, uint256 /* tokenId */) internal view override {
        require(balanceOf(to) + 1 <= _maxBalance);

        if(_soulbound) {
            require(from == address(0) || to == address(0));
        }
    }
}