pragma solidity ^0.5.12;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "../../common/Base.sol";
import "../../interfaces/token/IPoolTokenBalanceChangeRecipient.sol";

contract RewardDistributions is Base, IPoolTokenBalanceChangeRecipient {
    event RewardDistribution(address indexed rewardRoken, address indexed poolToken, uint256 amount, uint256 totalShares);
    event RewardClaim(address indexed user, address indexed rewardToken, uint256 amount);
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

    function poolTokenBalanceChanged(address user, uint256 newAmount) public {
        address token = _msgSender();
        require(isPoolToken(token), "PoolToken is not registered");
        claimDistributions(user);
        rewardBalances[user].shares[token] = newAmount;
    }

    /**
     * Claims reward tokens from distributions to user balance
     */
    function claimDistributions(address user) public {
        //TODO
    }

    /**
     * @notice Withdraw reward tokens for user
     * @param rewardToken Token to withdraw
     */
    function withdrawReward(address rewardToken) public {
        address user = _msgSender();
        uint256 amount = rewardBalances[user].rewards[rewardToken];
        require(amount > 0, "RewardDistributions: nothing to withdraw");
        IERC20(rewardToken).safeTransfer(user, amount);
        rewardBalances[user].rewards[rewardToken] = 0;
        emit RewardWithdraw(user, rewardToken, amount);
    }

    function distributeReward(address[] memory rewardTokens, uint256[] memory amounts) internal {
        //TODO
        //emit RewardDistribution(address indexed rewardRoken, address indexed poolToken, uint256 amount, uint256 totalShares)
    }


    function updateRewardBalance(uint256 fromDistribution, uint256 toDistribution, RewardBalance storage rb) internal view returns(uint256[] memory) {
        uint256 next = fromDistribution;
        while (next < toDistribution) {
            RewardTokenDistribution storage d = rewardDistributions[next];
            uint256 sh = rb.shares[d.poolToken];
            if (sh == 0) continue;
            for (uint256 i=0; i < d.rewardTokens.length; i++) {
                address rToken = tokens[i];
                uint256 distrAmount = d.amounts[rToken];
                rb.rewards[rToken] = rb.rewards[rToken].add(distrAmount.mul(sh).div(d.totalShares));
                //event RewardClaim(address indexed user, address indexed rewardToken, uint256 amount);
            }
            next++;
        }
        return totalInterest;
    }

    function isPoolToken(address token) internal view returns(bool);
    function registeredPoolTokens() internal view returns(address[] memory);
    
}