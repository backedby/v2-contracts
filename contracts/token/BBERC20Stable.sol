// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import "@backedby/v1-contracts/contracts/interfaces/IBBSubscriptionsFactory.sol";

contract BBERC20Stable is IERC20, IERC20Metadata {
    struct PathNode {
        AggregatorV3Interface aggregator;
        bool divisor;
    }

    PathNode[] public conversionPath;

    IERC20Metadata public immutable token;

    IBBSubscriptionsFactory public immutable bbSubscriptionsFactory;

    uint256 internal _transferFromTokenAmount;

    string internal _postfix;

    constructor(address tokenContract, string memory postfix, address bbSubsFactory, address[] memory aggregators, bool[] memory divisors) {
        token = IERC20Metadata(tokenContract);
        _postfix = postfix;
        bbSubscriptionsFactory = IBBSubscriptionsFactory(bbSubsFactory);

        require(aggregators.length > 0);
        require(aggregators.length == divisors.length);

        for(uint i = 0; i < aggregators.length; i++) {
            conversionPath.push(PathNode(AggregatorV3Interface(aggregators[i]), divisors[i]));
        }
    }

    function name() public view override returns (string memory) {
        return string(abi.encodePacked("BB", token.name(), _postfix));
    }

    function symbol() public view override returns (string memory) {
        return string(abi.encodePacked("BB", token.symbol(), _postfix));
    }

    function decimals() public view override returns (uint8) {
        return token.decimals();
    }

    function totalSupply() external view override returns (uint256) {
        return _tokenToStableAmount(token.totalSupply());
    }

    function balanceOf(address account) external view override returns (uint256) {
        return _tokenToStableAmount(token.balanceOf(account));
    }

    function transfer(address to, uint256 stableAmount) external override returns (bool) {
        require(msg.sender == _bbSubscriptions());

        uint256 tokenAmount = _stableToTokenAmount(stableAmount);
        token.transfer(to, tokenAmount);
        token.transfer(bbSubscriptionsFactory.getTreasury(), _transferFromTokenAmount - tokenAmount);
        
        return true;
    }

    function transferFrom(address from, address /*to*/, uint256 stableAmount) external override returns (bool) {
        require(msg.sender == _bbSubscriptions());

        if(token.balanceOf(address(this)) > 0) {
            token.transfer(bbSubscriptionsFactory.getTreasury(), token.balanceOf(address(this)));
        }

        uint256 tokenAmount = _stableToTokenAmount(stableAmount);
        token.transferFrom(from, address(this), tokenAmount);
        
        _transferFromTokenAmount = tokenAmount;

        return true;
    }

    function allowance(address owner, address /*spender*/) external view override returns (uint256) {
        return _tokenToStableAmount(token.allowance(owner, address(this)));
    }

    function approve(address /*spender*/, uint256 /*amount*/) external pure override returns (bool) {
        return true;
    }

    function _bbSubscriptions() internal view returns (address) {
        return bbSubscriptionsFactory.getDeployedSubscriptions(address(this));
    }

    //todo try to generalize these so that there is less repeating.
    function _tokenToStableAmount(uint256 amount) internal view returns (uint256) {
        for(uint i = 0; i < conversionPath.length; i++) {
            uint256 index = (conversionPath.length - 1) - i;

            (
                /*uint80 roundId*/,
                int256 answer,
                /*uint256 startedAt*/,
                /*uint256 updatedAt*/,
                /*uint80 answeredInRound*/
            ) = conversionPath[index].aggregator.latestRoundData();

            uint onee = (10 ** conversionPath[index].aggregator.decimals());

            uint dividend = uint(answer);
            uint divisor = onee;

            if(!conversionPath[index].divisor) {
                dividend = onee;
                divisor = uint(answer);
            }

            amount = amount * dividend / divisor;
        }

        return amount;
    }

    function _stableToTokenAmount(uint256 amount) internal view returns (uint256) {
        for(uint i = 0; i < conversionPath.length; i++) {
            (
                /*uint80 roundId*/,
                int256 answer,
                /*uint256 startedAt*/,
                /*uint256 updatedAt*/,
                /*uint80 answeredInRound*/
            ) = conversionPath[i].aggregator.latestRoundData();

            uint onee = (10 ** conversionPath[i].aggregator.decimals());

            uint dividend = onee;
            uint divisor = uint(answer);

            if(!conversionPath[i].divisor) {
                dividend = uint(answer);
                divisor = onee;
            }

            amount = amount * dividend / divisor;
        }

        return amount;
    }
}