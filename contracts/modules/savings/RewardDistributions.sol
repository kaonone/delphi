pragma solidity ^0.5.12;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "../../common/Base.sol";
import "../../interfaces/token/IPoolTokenBalanceChangeRecipient.sol";

contract RewardDistributions is Base, IPoolTokenBalanceChangeRecipient {
    event RewardWithdraw(address indexed user, address indexed token, uint256 amount);

    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    struct RewardTokenDistribution {
        uint256 totalShares;                // Total shares of PoolToken participating in this distribution
        mapping(address=>uint256) amounts;  // Maps address of reward token to amount beeing distributed
    }

    struct RewardBalance {
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
     * Withdraw reward tokens for user
     */
    function withdrawReward(address rewardToken) public {
        address user = _msgSender();
        uint256 amount = rewardBalances[user].rewards[rewardToken];
        require(amount > 0, "RewardDistributions: nothing to withdraw");
        IERC20(rewardToken).safeTransfer(user, amount);
        rewardBalances[user].rewards[rewardToken] = 0;
        emit RewardWithdraw(user, rewardToken, amount);
    }

    function distributeReward(address rewardToken, uint256 amount) public {
        //TODO
    }

    function isPoolToken(address token) internal view returns(bool);
}