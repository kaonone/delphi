pragma solidity ^0.5.12;

import "@openzeppelin/contracts/token/ERC721/ERC721Full.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721Burnable.sol";
import "@openzeppelin/contracts/drafts/Counters.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "../../lib/TransferHelper.sol";
import "../../test/FakeUniswapRouter.sol";

contract DCAModule is ERC721Full, ERC721Burnable {
    using SafeMath for uint256;
    using Counters for Counters.Counter;
    using TransferHelper for address;

    event DistributionCreated(
        address tokenAddress,
        uint256 amount,
        uint256 totalSupply
    );

    event DistributionsClaimed(
        uint256 tokenId,
        address distributionTokenAddress,
        uint256 amount,
        uint256 distributionIndex
    );

    Counters.Counter private _tokenIds;

    struct Account {
        uint256 balance;
        uint256 buyAmount;
        uint256 lastDistributionIndex;
    }

    struct Distribution {
        address tokenAddress;
        uint256 amount;
        uint256 totalSupply;
    }

    struct DistributionToken {
        string tokenSymbol;
        address tokenAddress;
    }

    Distribution[] public distributions;
    DistributionToken[] public distributionTokens;

    uint256 public periodTimestamp;
    uint256 public nextBuyTimestamp;
    uint256 public globalPeriodBuyAmount;

    address public router;

    mapping(uint256 => Account) private _accountOf;
    mapping(uint256 => uint256) public removeAfterDistribution;
    mapping(address => mapping(uint256 => uint256))
        public distributedTokenBalanceOf;

    enum Strategies {ONE, ALL}

    address public tokenToSell;

    Strategies public strategy;

    constructor(
        string memory name,
        string memory symbol,
        address _tokenToSell,
        uint256 _strategy,
        address _router,
        uint256 _periodTimestamp
    ) public ERC721Full(name, symbol) {
        tokenToSell = _tokenToSell;
        strategy = Strategies(_strategy);
        router = _router;
        periodTimestamp = _periodTimestamp;
        nextBuyTimestamp = now.add(_periodTimestamp);
    }

    function setDistributionToken(
        string calldata tokenSymbol,
        address tokenAddress
    ) external returns (bool) {
        require(
            (strategy == Strategies.ONE && distributionTokens.length <= 1) ||
                strategy == Strategies.ALL,
            "DCAModule-setDistributionToken: a strategy can contain only one token"
        );

        distributionTokens.push(
            DistributionToken({
                tokenSymbol: tokenSymbol,
                tokenAddress: tokenAddress
            })
        );

        return true;
    }

    function deposit(uint256 amount, uint256 buyAmount)
        external
        returns (bool)
    {
        tokenToSell.safeTransferFrom(_msgSender(), address(this), amount);

        if (balanceOf(_msgSender()) == 0) {
            _tokenIds.increment();

            uint256 newTokenId = _tokenIds.current();

            _mint(_msgSender(), newTokenId);

            _accountOf[newTokenId].balance = amount;

            _accountOf[newTokenId].buyAmount = buyAmount;

            globalPeriodBuyAmount = globalPeriodBuyAmount.add(buyAmount);

            uint256 removalPoint = distributions.length.add(
                _accountOf[newTokenId].balance.div(buyAmount)
            );

            removeAfterDistribution[removalPoint -
                1] = removeAfterDistribution[removalPoint - 1].add(buyAmount);
        } else {
            require(
                claimDistributions(),
                "DCAModule-deposit: claim distributions error"
            );

            uint256 tokenId = _tokensOfOwner(_msgSender())[0];

            _accountOf[tokenId].balance = _accountOf[tokenId].balance.add(
                amount
            );

            _accountOf[tokenId].buyAmount = buyAmount;

            globalPeriodBuyAmount = globalPeriodBuyAmount
                .sub(_accountOf[tokenId].buyAmount)
                .add(buyAmount);

            uint256 removalPoint = distributions.length.add(
                _accountOf[tokenId].balance.div(buyAmount)
            );

            removeAfterDistribution[removalPoint - 1] = buyAmount;
        }

        return true;
    }

    function withdraw(uint256 amount) external returns (bool) {
        require(
            claimDistributions(),
            "DCAModule-deposit: claim distributions error"
        );

        uint256 tokenId = _tokensOfOwner(_msgSender())[0];

        require(
            _accountOf[tokenId].balance >= amount,
            "DCAModule-withdraw: transfer amount exceeds balance"
        );

        _accountOf[tokenId].balance = _accountOf[tokenId].balance.sub(amount);

        tokenToSell.safeTransfer(_msgSender(), amount);

        return true;
    }

    function buy() external returns (bool) {
        require(now >= nextBuyTimestamp, "DCAModule-buy: not the time to buy");

        uint256 buyAmount = globalPeriodBuyAmount.div(
            distributionTokens.length
        );

        for (uint256 i = 0; i < distributionTokens.length; i++) {
            require(
                _swapAndCreateDistribution(
                    tokenToSell,
                    distributionTokens[i].tokenAddress,
                    buyAmount
                ),
                "DCAModule-buy: swap error"
            );
        }

        nextBuyTimestamp = nextBuyTimestamp.add(periodTimestamp);

        return true;
    }

    function claimDistributions() public returns (bool) {
        uint256 tokenId = _tokensOfOwner(_msgSender())[0];

        for (
            uint256 i = _accountOf[tokenId].lastDistributionIndex + 1;
            i < distributions.length;
            i++
        ) {
            if (_accountOf[tokenId].balance > 0) {
                uint256 amount = _accountOf[tokenId]
                    .buyAmount
                    .mul(distributions[i].totalSupply)
                    .div(distributions[i].amount);

                _accountOf[tokenId].balance = _accountOf[tokenId].balance.sub(
                    _accountOf[tokenId].buyAmount
                );

                distributedTokenBalanceOf[distributions[i]
                    .tokenAddress][tokenId] = distributedTokenBalanceOf[distributions[i]
                    .tokenAddress][tokenId]
                    .add(amount);

                _accountOf[tokenId].lastDistributionIndex = i;

                globalPeriodBuyAmount = globalPeriodBuyAmount.sub(
                    removeAfterDistribution[i]
                );
            } else {
                return true;
            }
        }

        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "ERC721: transfer caller is not owner or not approved"
        );

        _burn(from, tokenId);

        uint256 senderBalance = _accountOf[tokenId].balance;

        _accountOf[tokenId].balance = 0;

        uint256 recipientTokenId = _tokensOfOwner(to)[0];

        _accountOf[recipientTokenId].balance = _accountOf[recipientTokenId]
            .balance
            .add(senderBalance);
    }

    function _swapAndCreateDistribution(
        address tokenIn,
        address tokenOut,
        uint256 amount
    ) private returns (bool) {
        tokenIn.safeApprove(router, amount);

        uint256[2] memory amounts = FakeUniswapRouter(router).swap(
            tokenIn,
            tokenOut,
            globalPeriodBuyAmount
        );

        distributions.push(
            Distribution({
                tokenAddress: tokenOut,
                amount: amounts[0],
                totalSupply: amounts[1]
            })
        );

        return true;
    }
}
