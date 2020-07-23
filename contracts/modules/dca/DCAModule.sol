pragma solidity ^0.5.12;

import "@openzeppelin/contracts/token/ERC721/ERC721Full.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721Burnable.sol";
import "@openzeppelin/contracts/drafts/Counters.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "../../lib/TransferHelper.sol";
import "../../test/FakeUniswapRouter.sol";

/**
 * @dev Implementation of the {DCAModule} interface.
 *
 * Dollar-cost averaging (DCA) is an investment strategy
 * in which an investor divides up the total amount to be
 * invested across periodic purchases of a target asset in
 * an effort to reduce the impact of volatility on the overall
 * purchase.
 */
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
        mapping(address => uint256) balance;
        uint256 buyAmount;
        uint256 lastDistributionIndex;
        uint256 lastRemovalPointIndex;
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

    enum Strategies {ONE, ALL}

    address public tokenToSell;

    Strategies public strategy;

    /**
     * @dev Sets the values for {name}, {symbol}, {tokenToSell},
     * {strategy}, {router} and {periodTimestamp}
     *
     * All three of these values are immutable: they can only be set once during
     * construction.
     */
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

    /**
     * @dev Sets `tokenSymbol` and `tokenAddress` for DistributionToken struct,
     * that is stored in the `distributionTokens` array.
     *
     * @param tokenSymbol Token symbol.
     * @param tokenAddress Token address.
     *
     * @return Boolean value indicating whether the operation succeeded.
     *
     * Emits an {DistributionTokenAdded} event.
     */
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

    /**
     * @dev Makes a `tokenToSell` deposit and ERC721 token,
     * which is associated with the account. Increases the `tokenToSell` account balance,
     * launches `globalPeriodBuyAmount` and `removalPoint` recalculations if the ERC721
     * token already exist.
     * @param amount Deposit amount.
     * @param buyAmount Total amount to be invested across periodic
     * purchases of a target assets.
     *
     * @return Boolean value indicating whether the operation succeeded.
     *
     * Emits an {Deposit} event.
     */
    function deposit(uint256 amount, uint256 buyAmount)
        external
        returns (bool)
    {
        tokenToSell.safeTransferFrom(_msgSender(), address(this), amount);

        if (balanceOf(_msgSender()) == 0) {
            _tokenIds.increment();

            uint256 newTokenId = _tokenIds.current();

            _mint(_msgSender(), newTokenId);

            _accountOf[newTokenId].balance[tokenToSell] = amount;

            _accountOf[newTokenId].buyAmount = buyAmount;

            globalPeriodBuyAmount = globalPeriodBuyAmount.add(buyAmount);

            uint256 removalPoint = distributions.length.add(
                _accountOf[newTokenId].balance[tokenToSell].div(buyAmount)
            );

            removeAfterDistribution[removalPoint -
                1] = removeAfterDistribution[removalPoint - 1].add(buyAmount);
        } else {
            require(
                claimDistributions(),
                "DCAModule-deposit: claim distributions error"
            );

            uint256 tokenId = _tokensOfOwner(_msgSender())[0];

            _accountOf[tokenId].balance[tokenToSell] = _accountOf[tokenId]
                .balance[tokenToSell]
                .add(amount);

            removeAfterDistribution[_accountOf[tokenId]
                .lastRemovalPointIndex] = removeAfterDistribution[_accountOf[tokenId]
                .lastRemovalPointIndex]
                .sub(_accountOf[tokenId].buyAmount);

            globalPeriodBuyAmount = globalPeriodBuyAmount
                .sub(_accountOf[tokenId].buyAmount)
                .add(buyAmount);

            _accountOf[tokenId].buyAmount = buyAmount;

            uint256 removalPoint = distributions.length.add(
                _accountOf[tokenId].balance[tokenToSell].div(buyAmount)
            );

            removeAfterDistribution[removalPoint -
                1] = removeAfterDistribution[removalPoint - 1].add(buyAmount);
        }

        return true;
    }

    /**
     * @dev Makes a `token` withdrawal. Launches `removalPoint` recalculation
     *  if token address is equal to the `tokenToSell`.
     *
     * @param amount Withdrawal amount.
     * @param token Token address.
     *
     * @return Boolean value indicating whether the operation succeeded.
     *
     * Emits an {Withdrawal} event.
     */
    function withdraw(uint256 amount, address token) external returns (bool) {
        require(
            claimDistributions(),
            "DCAModule-deposit: claim distributions error"
        );

        uint256 tokenId = _tokensOfOwner(_msgSender())[0];

        if (token == tokenToSell) {
            require(
                _accountOf[tokenId].balance[tokenToSell] >= amount,
                "DCAModule-withdraw: transfer amount exceeds balance"
            );

            _accountOf[tokenId].balance[tokenToSell] = _accountOf[tokenId]
                .balance[tokenToSell]
                .sub(amount);

            removeAfterDistribution[_accountOf[tokenId]
                .lastRemovalPointIndex] = removeAfterDistribution[_accountOf[tokenId]
                .lastRemovalPointIndex]
                .sub(_accountOf[tokenId].buyAmount);

            uint256 removalPoint = distributions.length.add(
                _accountOf[tokenId].balance[tokenToSell].div(
                    _accountOf[tokenId].buyAmount
                )
            );

            removeAfterDistribution[removalPoint -
                1] = removeAfterDistribution[removalPoint - 1].add(
                _accountOf[tokenId].buyAmount
            );

            tokenToSell.safeTransfer(_msgSender(), amount);
        } else {
            require(
                _accountOf[tokenId].balance[token] >= amount,
                "DCAModule-withdraw: transfer amount exceeds balance"
            );

            _accountOf[tokenId].balance[token] = _accountOf[tokenId]
                .balance[token]
                .sub(amount);

            token.safeTransfer(_msgSender(), amount);
        }

        return true;
    }

    /**
     * @dev Makes a purchase of a target assets.
     *
     * @return Boolean value indicating whether the operation succeeded.
     *
     * Emits an {Purchase} and {DistributionCreated} events.
     */
    function purchase() external returns (bool) {
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

    /**
     * @dev Makes a target assets shares distribution.
     *
     * @return Boolean value indicating whether the operation succeeded.
     *
     * Emits an {DistributionsClaimed} event.
     */
    function claimDistributions() public returns (bool) {
        uint256 tokenId = _tokensOfOwner(_msgSender())[0];

        for (
            uint256 i = _accountOf[tokenId].lastDistributionIndex + 1;
            i < distributions.length;
            i++
        ) {
            if (
                _accountOf[tokenId].balance[distributions[i].tokenAddress] >=
                _accountOf[tokenId].buyAmount
            ) {
                uint256 amount = _accountOf[tokenId]
                    .buyAmount
                    .mul(distributions[i].totalSupply)
                    .div(distributions[i].amount);

                _accountOf[tokenId].balance[distributions[i]
                    .tokenAddress] = _accountOf[tokenId]
                    .balance[distributions[i].tokenAddress]
                    .sub(_accountOf[tokenId].buyAmount);

                _accountOf[tokenId].balance[distributions[i]
                    .tokenAddress] = _accountOf[tokenId]
                    .balance[distributions[i].tokenAddress]
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

    /**
     * @dev Transfers `tokenId` token from `from` to `to` and merges accounts data.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
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

        uint256 senderBalance = _accountOf[tokenId].balance[tokenToSell];

        _accountOf[tokenId].balance[tokenToSell] = 0;

        uint256 recipientTokenId = _tokensOfOwner(to)[0];

        _accountOf[recipientTokenId]
            .balance[tokenToSell] = _accountOf[recipientTokenId]
            .balance[tokenToSell]
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
            amount
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
