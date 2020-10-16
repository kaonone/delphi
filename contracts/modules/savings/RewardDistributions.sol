pragma solidity ^0.5.12;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "../../common/Base.sol";
import "../../interfaces/defi/IDefiProtocol.sol";
import "../access/AccessChecker.sol";
import "../token/PoolToken.sol";

contract RewardDistributions is Base, AccessChecker {
    using SafeMath for uint256;

    struct RewardTokenDistribution {
        address poolToken;                  // PoolToken which holders will receive reward
        uint256 totalShares;                // Total shares of PoolToken participating in this distribution
        address[] rewardTokens;             // List of reward tokens being distributed 
        mapping(address=>uint256) amounts; 
    }

    struct UserProtocolRewards {
        mapping(address=>uint256) amounts;  // Maps address of reward token to amount beeing distributed
    }
    struct RewardBalance {
        uint256 nextDistribution;
        mapping(address => uint256) shares;     // Maps PoolToken to amount of user shares participating in distributions
        mapping(address => UserProtocolRewards) rewardsByProtocol; //Maps PoolToken to ProtocolRewards struct (map of reward tokens to their balances);
    }

    RewardTokenDistribution[] rewardDistributions;
    mapping(address=>RewardBalance) rewardBalances; //Mapping users to their RewardBalance

    // function registeredPoolTokens() public view returns(address[] memory);

    // function userRewards(address user, address protocol, address[] calldata rewardTokens) external view returns(uint256[] memory){
    //     uint256[] memory amounts = new uint256[](rewardTokens.length);
    //     RewardBalance storage rb = rewardBalances[user];
    //     require(rb.nextDistribution == rewardDistributions.length, "RewardDistributions: rewards not calculated");
    //     for(uint256 i=0; i<amounts.length; i++) {
    //         address rt = rewardTokens[i];
    //         amounts[i] = rb.rewardsByProtocol[protocol].amounts[rt];
    //     }
    //     return amounts;
    // }

    // function rewardBalanceOf(address user, address poolToken, address rewardToken) public view returns(uint256) {
    //     RewardBalance storage rb = rewardBalances[user];
    //     UserProtocolRewards storage upr = rb.rewardsByProtocol[poolToken];
    //     uint256 balance = upr.amounts[rewardToken];
    //     uint256 next = rb.nextDistribution;
    //     while (next < rewardDistributions.length) {
    //         RewardTokenDistribution storage d = rewardDistributions[next];
    //         next++;

    //         uint256 sh = rb.shares[d.poolToken];
    //         if (sh == 0 || poolToken != d.poolToken) continue;
    //         uint256 distrAmount = d.amounts[rewardToken];
    //         balance = balance.add(distrAmount.mul(sh).div(d.totalShares));
    //     }
    //     return balance;
    // }

    function rewardBalanceOf(address user, address poolToken, address[] memory rewardTokens) public view returns(uint256[] memory) {
        RewardBalance storage rb = rewardBalances[user];
        UserProtocolRewards storage upr = rb.rewardsByProtocol[poolToken];
        uint256[] memory balances = new uint256[](rewardTokens.length);
        uint256 i;
        for(i=0; i < rewardTokens.length; i++){
            balances[i] = upr.amounts[rewardTokens[i]];
        }
        uint256 next = rb.nextDistribution;
        while (next < rewardDistributions.length) {
            RewardTokenDistribution storage d = rewardDistributions[next];
            next++;

            uint256 sh = rb.shares[d.poolToken];
            if (sh == 0 || poolToken != d.poolToken) continue;
            for(i=0; i < rewardTokens.length; i++){
                uint256 distrAmount = d.amounts[rewardTokens[i]];
                balances[i] = balances[i].add(distrAmount.mul(sh).div(d.totalShares));
            }
        }
        return balances;
    }


    // /**
    // * @notice Updates user balance
    // * @param user User address 
    // */
    // function updateRewardBalance(address user) public {
    //     _updateRewardBalance(user, rewardDistributions.length);
    // }

    // /**
    // * @notice Updates user balance
    // * @param user User address 
    // * @param toDistribution Index of distribution next to the last one, which should be processed
    // */
    // function updateRewardBalance(address user, uint256 toDistribution) public {
    //     _updateRewardBalance(user, toDistribution);
    // }

    // function _updateRewardBalance(address user, uint256 toDistribution) internal {
    //     require(toDistribution <= rewardDistributions.length, "RewardDistributions: toDistribution index is too high");
    //     RewardBalance storage rb = rewardBalances[user];
    //     uint256 next = rb.nextDistribution;
    //     if(next >= toDistribution) return;

    //     if(next == 0 && rewardDistributions.length > 0){
    //         //This might be a new user, if so we can skip previous distributions
    //         address[] memory poolTokens = registeredPoolTokens();
    //         bool hasDeposit;
    //         for(uint256 i=0; i< poolTokens.length; i++){
    //             address poolToken = poolTokens[i];
    //             if(rb.shares[poolToken] != 0) {
    //                 hasDeposit = true;
    //                 break;
    //             }
    //         }
    //         if(!hasDeposit){
    //             rb.nextDistribution = rewardDistributions.length;
    //             return;
    //         }
    //     }

    //     while (next < toDistribution) {
    //         RewardTokenDistribution storage d = rewardDistributions[next];
    //         next++;
    //         uint256 sh = rb.shares[d.poolToken];
    //         if (sh == 0) continue;
    //         UserProtocolRewards storage upr = rb.rewardsByProtocol[d.poolToken]; 
    //         for (uint256 i=0; i < d.rewardTokens.length; i++) {
    //             address rToken = d.rewardTokens[i];
    //             uint256 distrAmount = d.amounts[rToken];
    //             upr.amounts[rToken] = upr.amounts[rToken].add(distrAmount.mul(sh).div(d.totalShares));

    //         }
    //     }
    //     rb.nextDistribution = next;
    // }

}