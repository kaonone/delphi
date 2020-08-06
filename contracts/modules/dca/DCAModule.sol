pragma solidity ^0.5.17;

// !!!!!!!
// TODO purchase(), _swapAndMakeDistribution(), withdrawRewardAndMakeDistribution()
// !!!!!!!

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC721/ERC721Full.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC721/ERC721Burnable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/drafts/Counters.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "../../interfaces/uniswap/IUniswapV2Router02.sol";
import "../../interfaces/savings/ISavingsModule.sol";
import "../../utils/TransferHelper.sol";
import "../../utils/Normalization.sol";
import "./DCAOperatorRole.sol";
import "../../common/Module.sol";

contract DCAModule is Module, ERC721Full, ERC721Burnable, DCAOperatorRole {
    using SafeMath for uint256;
    using TransferHelper for address;
    using Normalization for uint256;
    using Counters for Counters.Counter;

    function deposit(uint256 amount, uint256 newBuyAmount) external {
        tokenToSell.safeTransferFrom(_msgSender(), address(this), amount);

        // if new user
        if (balanceOf(_msgSender()) == 0) {
            uint256 tokenId = _registerNewAccount();

            // returns normalized amount of pTokens (mint)
            (uint256 nDeposit, uint256 dDeposit) = _depositToPool(
                tokenToSell,
                amount
            );

            _refreshAccount(tokenId, dDeposit, 0, newBuyAmount, true);

            emit Deposit(_msgSender(), dDeposit, nDeposit, newBuyAmount);

            _accountOf[newTokenId].nextDistributionIndex = distributions.length;

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

            emit Deposit(
                _msgSender(),
                tokenToSell,
                dDeposit,
                nDeposit,
                newBuyAmount
            );
        }
    }

    function withdraw(address token, uint256 amount) external {
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
                0,
                false
            );
        }

        token.safeTransfer(_msgSender(), dWithdrawal);

        emit Withdrawal(_msgSender(), token, dWithdrawal, nWithdrawal);
    }

    function getTokenIdByAddress(address user) public returns (uint256) {
        return _tokensOfOwner(user)[0];
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

        if (newBuyAmount > 0) {
            // update buyAmount
            _accountOf[tokenId].buyAmount = newBuyAmount;

            // remove oldBuyAmount from globalPeriodBuyAmount and add newBuyAmount
            globalPeriodBuyAmount = globalPeriodBuyAmount.sub(oldBuyAmount).add(
                newBuyAmount
            );
        }

        // remove oldBuyAmount from removeAfterDistribution
        if (oldBuyAmount > 0) {
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
    }

    function _calculatePayout(uint256 distibutionIndex, uint256 buyAmount)
        private
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
            .tokenAddress] = _accountOf[tokenId]
            .balance[distributions[distibutionIndex].tokenAddress]
            .add(amount);
    }

    function _claimDistributions() private returns (bool) {
        uint256 tokenId = getTokenIdByAddress(_msgSender());

        uint256 dividedBuyAmount = _accountOf[tokenId].buyAmount.div(
            distributionTokens.length
        );

        for (
            uint256 i = _accountOf[tokenId].nextDistributionIndex;
            i < distributions.length;
            i++
        ) {
            if (distributions[i].tokenAddress == tokenToSell) {
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

                    _accountOf[tokenId].nextDistributionIndex = i.add(0x0001);
                }
            }
        }
    }

    function _registerNewAccount() private returns (uint256) {
        _tokenIds.increment();

        uint256 tokenId = _tokenIds.current();

        _mint(_msgSender(), newTokenId);

        return tokenId;
    }

    function _calculateWithdrawalMaxNAmount(address token, uint256 amount)
        private
        returns (uint256)
    {
        // normalized withdrawal amount
        uint256 nAmount = amount.normalize(tokenDataOf[token].decimals);

        // normalized withdrawal amount + fee
        return nAmount.add(nAmount.mul(protocolMaxFee).div(feeFoundation));
    }

    function _calculateYieldAndMakeDistribution(
        address token,
        uint256 prevPoolTokenBalance,
        uint256 nWithdrawal
    ) private {
        uint256 yield = IERC20(tokenDataOf[token].poolToken)
            .balanceOf(address(this))
            .sub(prevPoolTokenBalance)
            .sub(nWithdrawal);

        if (yield > 0) {
            distributions.push(
                Distribution({
                    tokenAddress: token,
                    amountIn: globalPeriodBuyAmount,
                    amountOut: yield.denormalize(tokenDataOf[token].decimals)
                })
            );
        }
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

        return (nDeposit, dDeposit);
    }

    function _withdrawFromPool(address token, uint256 amount)
        private
        returns (uint256, uint256)
    {
        uint256 prevPoolTokenBalance = IERC20(tokenDataOf[token].poolToken)
            .balanceOf(address(this));

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

        _calculateYieldAndMakeDistribution(
            token,
            prevPoolTokenBalance,
            nWithdrawal
        );

        return (nWithdrawal, dWithdrawal);
    }
}
