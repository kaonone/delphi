pragma solidity ^0.5.12;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "../../common/Base.sol";
import "../../interfaces/token/IPoolTokenBalanceChangeRecipient.sol";
import "../token/PoolToken.sol";

contract RewardDistributions is Base, IPoolTokenBalanceChangeRecipient {
    event RewardDistribution(address indexed poolToken, address indexed rewardRoken, uint256 amount, uint256 totalShares);
    event RewardWithdraw(address indexed user, address indexed rewardToken, uint256 amount);

    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    struct RewardTokenDistribution {
        address poolToken;                  // PoolToken which holders will receive reward
        uint256 totalShares;                // Total shares of PoolToken participating in this distribution
        address[] rewardTokens;             // List of reward tokens being distributed 
        mapping(address=>uint256) amounts;  // Maps address of reward token to amount beeing distributed
    }

    struct RewardBalance {
        uint256 nextDistribution;
        mapping(address => uint256) shares;     // Maps PoolToken to amount of user shares participating in distributions
        mapping(address => uint256) rewards;    // Maps Reward tokens to user balances of this reward tokens
    }

    RewardTokenDistribution[] rewardDistributions;
    mapping(address=>RewardBalance) rewardBalances; //Mapping users to their RewardBalance

    function poolTokenBalanceChanged(address user) public {
        address token = _msgSender();
        require(isPoolToken(token), "RewardDistributions: PoolToken is not registered");
        _updateRewardBalance(user, rewardDistributions.length);
        uint256 newAmount = PoolToken(token).distributionBalanceOf(user);
        rewardBalances[user].shares[token] = newAmount;
    }

    /**
     * @notice Withdraw reward tokens for user
     * @param rewardTokens Array of tokens to withdraw
     */
    function withdrawReward(address[] memory rewardTokens) public returns(uint256[] memory){
        address user = _msgSender();
        uint256[] memory rAmounts = new uint256[](rewardTokens.length);
        updateRewardBalance(user);
        for(uint256 i=0; i < rewardTokens.length; i++) {
            rAmounts[i] = _withdrawReward(user, rewardTokens[i]);
        }
        return rAmounts;
    }

    /**
     * @notice Withdraw reward tokens for user
     * @param rewardToken Token to withdraw
     */
    function withdrawReward(address rewardToken) public returns(uint256){
        address user = _msgSender();
        updateRewardBalance(user);
        return _withdrawReward(user, rewardToken);
    }

    function rewardBalanceOf(address user, address[] memory rewardTokens) public view returns(uint256[] memory) {
        uint256[] memory amounts = new uint256[](rewardTokens.length);
        for(uint256 i=0; i < rewardTokens.length; i++) {
            amounts[i] = rewardBalanceOf(user, rewardTokens[i]);
        }
        return amounts;
    }

    function rewardBalanceOf(address user, address rewardToken) public view returns(uint256 amounts) {
        RewardBalance storage rb = rewardBalances[user];
        uint256 balance = rb.rewards[rewardToken];
        uint256 next = rb.nextDistribution;
        while (next < rewardDistributions.length) {
            RewardTokenDistribution storage d = rewardDistributions[next];
            uint256 sh = rb.shares[d.poolToken];
            if (sh == 0) continue;
            uint256 distrAmount = d.amounts[rewardToken];
            balance = balance.add(distrAmount.mul(sh).div(d.totalShares));
            next++;
        }
        return balance;
    }

    /**
    * @notice Updates user balance
    * @param user User address 
    */
    function updateRewardBalance(address user) public {
        _updateRewardBalance(user, rewardDistributions.length);
    }

    /**
    * @notice Updates user balance
    * @param user User address 
    * @param toDistribution Index of distribution next to the last one, which should be processed
    */
    function updateRewardBalance(address user, uint256 toDistribution) public {
        _updateRewardBalance(user, toDistribution);
    }


    /**
    * @notice Create reward distribution
    */
    function distributeReward(address poolToken, address[] memory rewardTokens, uint256[] memory amounts) internal {
        rewardDistributions.push(RewardTokenDistribution({
            poolToken: poolToken,
            totalShares: PoolToken(poolToken).distributionTotalSupply(),
            rewardTokens:rewardTokens
        }));
        uint256 idx = rewardDistributions.length - 1;
        RewardTokenDistribution storage rd = rewardDistributions[idx];
        for(uint256 i=0; i < rewardTokens.length; i++) {
            rd.amounts[rewardTokens[i]] = amounts[i];  
            emit RewardDistribution(poolToken, rewardTokens[i], amounts[i], rd.totalShares);
        }
    }

    function _withdrawReward(address user, address rewardToken) internal returns(uint256) {
        uint256 amount = rewardBalances[user].rewards[rewardToken];
        require(amount > 0, "RewardDistributions: nothing to withdraw");
        IERC20(rewardToken).safeTransfer(user, amount);
        rewardBalances[user].rewards[rewardToken] = 0;
        emit RewardWithdraw(user, rewardToken, amount);
        return amount;
    }

    function _updateRewardBalance(address user, uint256 toDistribution) internal {
        require(toDistribution <= rewardDistributions.length, "RewardDistributions: toDistribution index is too high");
        RewardBalance storage rb = rewardBalances[user];
        uint256 next = rb.nextDistribution;
        if(next >= toDistribution) return;
        while (next < toDistribution) {
            RewardTokenDistribution storage d = rewardDistributions[next];
            uint256 sh = rb.shares[d.poolToken];
            if (sh == 0) continue;
            for (uint256 i=0; i < d.rewardTokens.length; i++) {
                address rToken = d.rewardTokens[i];
                uint256 distrAmount = d.amounts[rToken];
                rb.rewards[rToken] = rb.rewards[rToken].add(distrAmount.mul(sh).div(d.totalShares));
            }
            next++;
        }
        rb.nextDistribution = next;
    }

    function isPoolToken(address token) internal view returns(bool);
}