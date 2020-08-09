pragma solidity ^0.5.17;

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC721/ERC721Full.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC721/ERC721Burnable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/drafts/Counters.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "../../interfaces/uniswap/IUniswapV2Router02.sol";
import "../../interfaces/savings/ISavingsModule.sol";
import "../../interfaces/dca/IDCAFullBalanceHelper.sol";
import "../../utils/TransferHelper.sol";
import "../../utils/Normalization.sol";
import "./DCAOperatorRole.sol";
import "../../common/Module.sol";

contract DCAModule is Module, ERC721Full, ERC721Burnable, DCAOperatorRole {
    using SafeMath for uint256;
    using TransferHelper for address;
    using Normalization for uint256;
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIds;

    event Deposit(
        address user,
        address token,
        uint256 amount,
        uint256 newBuyAmount
    );

    event Withdrawal(address user, address token, uint256 amount);

    struct Account {
        mapping(address => uint256) balance;
        uint256 buyAmount;
        uint256 nextDistributionIndex;
        uint256 lastRemovalPointIndex;
    }

    struct Distribution {
        address token;
        uint256 amountIn;
        uint256 amountOut;
    }

    struct TokenData {
        uint256 decimals;
        address pool; // Reward
        address protocol;
        address poolToken;
    }

    Distribution[] public distributions;
    address[] public tokensToBuy;
    address[] public rewardPools;

    uint256 public periodTimestamp;
    uint256 public nextBuyTimestamp;
    uint256 public globalPeriodBuyAmount;
    uint256 public deadline; // uniswap v2 deadline
    uint256 public protocolMaxFee; // 1e18 fee foundation

    address public router;
    address public tokenToSell;
    address public dcaFullBalanceHelper;

    mapping(uint256 => Account) public _accountOf;
    mapping(uint256 => uint256) public removeAfterDistribution;
    mapping(address => TokenData) public tokenDataOf;
    mapping(address => uint256) public prevPoolTokenBalanceOf;
    mapping(address => bool) private inRewardPools;

    function initialize(
        string calldata _name,
        string calldata _symbol,
        address _osPool,
        address _tokenToSell,
        address[] calldata _tokensToBuy,
        address _router,
        uint256 _periodTimestamp,
        address bot
    ) external initializer {
        Module.initialize(_osPool);

        DCAOperatorRole.initialize(_msgSender());

        ERC721.initialize();
        ERC721Enumerable.initialize();
        ERC721Metadata.initialize(_name, _symbol);

        _setTokensToBuy(_tokensToBuy);

        tokenToSell = _tokenToSell;
        router = _router;
        periodTimestamp = _periodTimestamp;
        nextBuyTimestamp = now.add(_periodTimestamp);
    }

    // GETTERS
    function getTokenIdByAddress(address userAddress)
        public
        view
        returns (uint256)
    {
        return _tokensOfOwner(userAddress)[0];
    }

    function getAccountBuyAmount(uint256 tokenId)
        public
        view
        returns (uint256)
    {
        return _accountOf[tokenId].buyAmount;
    }

    function getFullAccountBalances(address account, address[] calldata tokens)
        external
        returns (uint256[] memory)
    {
        _claimDistributions();

        uint256 tokenId = getTokenIdByAddress(account);

        uint256[] memory balances = new uint256[](tokens.length);

        for (uint256 i = 0; i < tokens.length; i++) {
            balances[i] = _accountOf[tokenId].balance[tokens[i]];
        }

        return balances;
    }

    function getFullAccountBalances(address account)
        external
        returns (address[] memory, uint256[] memory)
    {
        return
            IDCAFullBalanceHelper(dcaFullBalanceHelper).getFullAccountBalances(
                address(this),
                account
            );
    }

    // SETTERS
    function setTokenData(
        address token,
        uint256 decimals,
        address pool,
        address protocol,
        address poolToken
    ) external onlyDCAOperator returns (bool) {
        tokenDataOf[token] = TokenData({
            decimals: decimals,
            pool: pool,
            protocol: protocol,
            poolToken: poolToken
        });

        if (!inPools[pool]) {
            rewardPools.push(pool);
            inPools[pool] = true;
        }

        return true;
    }

    function setDeadline(uint256 newDeadline) external onlyDCAOperator {
        deadline = newDeadline;
    }

    function setProtocolMaxFee(uint256 maxFee) external onlyDCAOperator {
        protocolMaxFee = maxFee;
    }

    // CORE
    function deposit(uint256 amount, uint256 newBuyAmount)
        external
        returns (uint256, uint256)
    {
        tokenToSell.safeTransferFrom(_msgSender(), address(this), amount);

        // if new user
        if (balanceOf(_msgSender()) == 0) {
            uint256 tokenId = _registerNewAccount();

            _withdrawRewardsAndMakeDistribution();

            _accountOf[tokenId].nextDistributionIndex = distributions.length;

            // returns normalized amount of pTokens (mint)
            (uint256 nDeposit, uint256 dDeposit) = _depositToPool(
                tokenToSell,
                amount
            );

            _refreshAccount(tokenId, dDeposit, 0, newBuyAmount, true);

            emit Deposit(_msgSender(), tokenToSell, amount, newBuyAmount);

            return (nDeposit, dDeposit);

            // if existing user
        } else {
            _claimDistributions();

            uint256 tokenId = getTokenIdByAddress(_msgSender());

            // returns normalized amount of pTokens (mint)
            (uint256 nDeposit, uint256 dDeposit) = _depositToPool(
                tokenToSell,
                amount
            );

            _refreshAccount(
                tokenId,
                dDeposit,
                _accountOf[tokenId].buyAmount,
                newBuyAmount,
                true
            );

            emit Deposit(_msgSender(), tokenToSell, amount, newBuyAmount);

            return (nDeposit, dDeposit);
        }
    }

    function withdraw(address token, uint256 amount)
        external
        returns (uint256, uint256)
    {
        _claimDistributions();

        uint256 tokenId = getTokenIdByAddress(_msgSender());

        require(
            _accountOf[tokenId].balance[token] >= amount,
            "DCAModule-withdraw: withdraw amount exceeds balance"
        );

        // returns normalized amount of pTokens (burn)
        (uint256 nWithdrawal, uint256 dWithdrawal) = _withdrawFromPool(
            token,
            amount
        );

        if (token == tokenToSell) {
            _refreshAccount(
                tokenId,
                dWithdrawal,
                _accountOf[tokenId].buyAmount,
                _accountOf[tokenId].buyAmount,
                false
            );
        }

        token.safeTransfer(_msgSender(), dWithdrawal);

        emit Withdrawal(_msgSender(), token, amount);

        return (nWithdrawal, dWithdrawal);
    }

    function purchase() external onlyDCAOperator {
        require(now >= nextBuyTimestamp, "DCAModule-purchase: not time to buy");

        uint256 dividedBuyAmount = _calculateDividedBuyAmount();

        // returns amounts of original tokens and pool tokens (burn)
        (, uint256 dWithdrawal) = _withdrawFromPool(
            tokenToSell,
            globalPeriodBuyAmount
        );

        tokenToSell.safeApprove(router, dWithdrawal);

        for (uint256 i = 0; i < tokensToBuy.length; i++) {
            // uniswap path [tokenToSell, tokenToBuy]
            address[] memory path = new address[](2);
            path[0] = tokenToSell;
            path[1] = tokensToBuy[i];

            _swapAndCreateDistribution(dividedBuyAmount, path);
        }

        nextBuyTimestamp = nextBuyTimestamp.add(periodTimestamp);

        globalPeriodBuyAmount = globalPeriodBuyAmount.sub(
            removeAfterDistribution[distributions
                .length
                .div(tokensToBuy.length)
                .sub(0x0001)]
        );

        // event
    }

    // PRIVATE (HELPERS)
    function _setTokensToBuy(address[] memory tokens) private {
        for (uint256 i = 0; i < tokens.length; i++) {
            tokensToBuy.push(tokens[i]);
        }
    }

    function _refreshAccount(
        uint256 tokenId,
        uint256 amount,
        uint256 oldBuyAmount,
        uint256 newBuyAmount,
        bool isIncrementBalance
    ) private {
        // inc or dec tokenToSell balance
        if (isIncrementBalance) {
            _accountOf[tokenId].balance[tokenToSell] = _accountOf[tokenId]
                .balance[tokenToSell]
                .add(amount);
        } else {
            _accountOf[tokenId].balance[tokenToSell] = _accountOf[tokenId]
                .balance[tokenToSell]
                .sub(amount);
        }

        if (newBuyAmount != oldBuyAmount) {
            // update buyAmount
            _accountOf[tokenId].buyAmount = newBuyAmount; // ?

            // remove oldBuyAmount from globalPeriodBuyAmount and add newBuyAmount
            globalPeriodBuyAmount = globalPeriodBuyAmount.sub(oldBuyAmount).add(
                newBuyAmount
            );
        }

        // remove oldBuyAmount from removeAfterDistribution
        removeAfterDistribution[_accountOf[tokenId]
            .lastRemovalPointIndex] = removeAfterDistribution[_accountOf[tokenId]
            .lastRemovalPointIndex]
            .sub(oldBuyAmount);

        // calculate new removalPoint
        uint256 removalPoint = distributions
            .length
            .add(_accountOf[tokenId].balance[tokenToSell].div(newBuyAmount))
            .sub(0x0001);

        // add newBuyAmount from removeAfterDistribution
        removeAfterDistribution[removalPoint] = removeAfterDistribution[removalPoint]
            .add(newBuyAmount);

        _accountOf[tokenId].lastRemovalPointIndex = removalPoint;
    }

    function _calculatePayout(uint256 distibutionIndex, uint256 buyAmount)
        private
        view
        returns (uint256)
    {
        return
            buyAmount.mul(distributions[distibutionIndex].amountOut).div(
                distributions[distibutionIndex].amountIn
            );
    }

    function _subBuyAmountAndUpdateBalance(
        uint256 tokenId,
        uint256 distibutionIndex,
        uint256 buyAmount,
        uint256 amount
    ) private returns (uint256) {
        _accountOf[tokenId].balance[tokenToSell] = _accountOf[tokenId]
            .balance[tokenToSell]
            .sub(buyAmount);

        _accountOf[tokenId].balance[distributions[distibutionIndex]
            .token] = _accountOf[tokenId]
            .balance[distributions[distibutionIndex].token]
            .add(amount);
    }

    function _calculateDividedBuyAmount() private view returns (uint256) {
        return globalPeriodBuyAmount.div(tokensToBuy.length);
    }

    function _withdrawRewardsAndMakeDistribution() private {
        for (uint256 i = 0; i < rewardPools.length; i++) {
            address[] memory rewardTokens = ISavingsModule(rewardPools[i])
                .supportedRewardTokens();

            uint256[] memory rAmounts = ISavingsModule(rewardPools[i])
                .withdrawReward(rewardTokens);

            for (uint256 j = 0; j < rewardTokens.length; j++) {
                _makeDistribution(
                    rewardTokens[j],
                    globalPeriodBuyAmount,
                    rAmounts[j]
                );
            }
        }
    }

    function _claimDistributions() private returns (bool) {
        _withdrawRewardsAndMakeDistribution();

        uint256 tokenId = getTokenIdByAddress(_msgSender());

        uint256 dividedBuyAmount = _calculateDividedBuyAmount();

        for (
            uint256 i = _accountOf[tokenId].nextDistributionIndex;
            i < distributions.length;
            i++
        ) {
            if (distributions[i].token == tokenToSell) {
                uint256 amount = _calculatePayout(
                    i,
                    _accountOf[tokenId].buyAmount
                );

                _refreshAccount(
                    tokenId,
                    amount,
                    _accountOf[tokenId].buyAmount,
                    0,
                    true
                );
            } else {
                if (
                    _accountOf[tokenId].balance[tokenToSell] >= dividedBuyAmount
                ) {
                    uint256 amount = _calculatePayout(i, dividedBuyAmount);

                    _subBuyAmountAndUpdateBalance(
                        tokenId,
                        i,
                        dividedBuyAmount,
                        amount
                    );
                }
            }
        }

        _accountOf[tokenId].nextDistributionIndex = distributions.length;
    }

    function _registerNewAccount() private returns (uint256) {
        _tokenIds.increment();

        uint256 tokenId = _tokenIds.current();

        _mint(_msgSender(), tokenId);

        return tokenId;
    }

    function _calculateWithdrawalMaxNAmount(address token, uint256 amount)
        private
        view
        returns (uint256)
    {
        // normalized withdrawal amount
        uint256 nAmount = amount.normalize(tokenDataOf[token].decimals);

        // normalized withdrawal amount + fee
        return nAmount.add(nAmount.mul(protocolMaxFee).div(1e18));
    }

    function _makeDistribution(
        address token,
        uint256 amountIn,
        uint256 amountOut
    ) private {
        distributions.push(
            Distribution({
                token: token,
                amountIn: amountIn,
                amountOut: amountOut
            })
        );
    }

    function _calculateYieldAndMakeDistribution(
        address token,
        uint256 nAmount,
        bool isIncrementBalance
    ) private {
        uint256 actualBalance = IERC20(tokenDataOf[token].poolToken).balanceOf(
            address(this)
        );

        uint256 yield = 0;

        if (isIncrementBalance) {
            yield = actualBalance.add(nAmount).sub(
                prevPoolTokenBalanceOf[token]
            );
        } else {
            yield = actualBalance.sub(nAmount).sub(
                prevPoolTokenBalanceOf[token]
            );
        }

        if (yield > 0)
            _makeDistribution(
                token,
                globalPeriodBuyAmount,
                yield.denormalize(tokenDataOf[token].decimals)
            );
    }

    function _depositToPool(address token, uint256 amount)
        private
        returns (uint256, uint256)
    {
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);

        tokens[0] = token;
        amounts[0] = amount;

        token.safeApprove(tokenDataOf[token].pool, amount);

        // normalized deposit amount
        uint256 nDeposit = ISavingsModule(tokenDataOf[token].pool).deposit(
            tokenDataOf[token].protocol,
            tokens,
            amounts
        );

        // denormalized deposit amount
        uint256 dDeposit = nDeposit.denormalize(tokenDataOf[token].decimals);

        _calculateYieldAndMakeDistribution(token, nDeposit, true);

        prevPoolTokenBalanceOf[token] = IERC20(tokenDataOf[token].poolToken)
            .balanceOf(address(this));

        return (nDeposit, dDeposit);
    }

    function _withdrawFromPool(address token, uint256 amount)
        private
        returns (uint256, uint256)
    {
        // normalized withdrawal amount (burn)
        uint256 nWithdrawal = ISavingsModule(tokenDataOf[token].pool).withdraw(
            tokenDataOf[token].protocol,
            token,
            amount,
            _calculateWithdrawalMaxNAmount(token, amount)
        );

        // denormalized withdrawal amount (burn)
        uint256 dWithdrawal = nWithdrawal.denormalize(
            tokenDataOf[token].decimals
        );

        _calculateYieldAndMakeDistribution(token, nWithdrawal, false);

        prevPoolTokenBalanceOf[token] = IERC20(tokenDataOf[token].poolToken)
            .balanceOf(address(this));

        return (nWithdrawal, dWithdrawal);
    }

    function _swapAndCreateDistribution(uint256 amountIn, address[] memory path)
        private
    {
        uint256[] memory amountsOut = IUniswapV2Router02(router).getAmountsOut(
            amountIn,
            path
        );

        uint256[] memory amounts = IUniswapV2Router02(router)
            .swapExactTokensForTokens(
            amountIn,
            amountsOut[1],
            path,
            address(this),
            deadline
        );

        // returns normalized amount of pTokens (mint)
        (, uint256 dDeposit) = _depositToPool(path[1], amounts[1]);

        _makeDistribution(path[1], amounts[0], dDeposit);
    }
}
