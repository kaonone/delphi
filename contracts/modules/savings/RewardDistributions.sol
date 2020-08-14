pragma solidity ^0.5.12;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "../../common/Base.sol";
import "../../interfaces/token/IPoolTokenBalanceChangeRecipient.sol";
import "../../interfaces/defi/IDefiProtocol.sol";
import "../access/AccessChecker.sol";
import "../token/PoolToken.sol";

contract RewardDistributions is Base, IPoolTokenBalanceChangeRecipient, AccessChecker {
    event RewardDistribution(address indexed poolToken, address indexed rewardRoken, uint256 amount, uint256 totalShares);
    event RewardWithdraw(address indexed user, address indexed rewardToken, uint256 amount);

    using SafeERC20 for IERC20;
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

    function poolTokenByProtocol(address _protocol) public view returns(address);
    function protocolByPoolToken(address _protocol) public view returns(address);
    function registeredPoolTokens() public view returns(address[] memory);
    function supportedRewardTokens() public view returns(address[] memory);

    function poolTokenBalanceChanged(address user) public {
        address token = _msgSender();
        require(isPoolToken(token), "RewardDistributions: PoolToken is not registered");
        _updateRewardBalance(user, rewardDistributions.length);
        uint256 newAmount = PoolToken(token).distributionBalanceOf(user);
        rewardBalances[user].shares[token] = newAmount;
    }

    function withdrawReward() public returns(uint256[] memory) {
        return withdrawReward(supportedRewardTokens());
    }

    /**
     * @notice Withdraw reward tokens for user
     * @param rewardTokens Array of tokens to withdraw
     */
    function withdrawReward(address[] memory rewardTokens)
    public operationAllowed(IAccessModule.Operation.Withdraw)
    returns(uint256[] memory)
    {
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
    function withdrawReward(address rewardToken) 
    public operationAllowed(IAccessModule.Operation.Withdraw)
    returns(uint256){
        address user = _msgSender();
        updateRewardBalance(user);
        return _withdrawReward(user, rewardToken);
    }

    function withdrawReward(address poolToken, address rewardToken) 
    public operationAllowed(IAccessModule.Operation.Withdraw)
    returns(uint256){
        address user = _msgSender();
        updateRewardBalance(user);
        return _withdrawReward(user, poolToken, rewardToken);
    }

    function rewardBalanceOf(address user, address[] memory rewardTokens) public view returns(uint256[] memory) {
        uint256[] memory amounts = new uint256[](rewardTokens.length);
        address[] memory poolTokens = registeredPoolTokens();
        for(uint256 i=0; i < rewardTokens.length; i++) {
            for(uint256 j=0; j < poolTokens.length; i++) {
                amounts[i] = amounts[i].add(rewardBalanceOf(user, poolTokens[j], rewardTokens[i]));
            }
        }
        return amounts;
    }

    function rewardBalanceOf(address user, address poolToken, address[] memory rewardTokens) public view returns(uint256[] memory) {
        uint256[] memory amounts = new uint256[](rewardTokens.length);
        for(uint256 i=0; i < rewardTokens.length; i++) {
            amounts[i] = rewardBalanceOf(user, poolToken, rewardTokens[i]);
        }
        return amounts;
    }

    function rewardBalanceOf(address user, address poolToken, address rewardToken) public view returns(uint256 amounts) {
        RewardBalance storage rb = rewardBalances[user];
        UserProtocolRewards storage upr = rb.rewardsByProtocol[poolToken];
        uint256 balance = upr.amounts[rewardToken];
        uint256 next = rb.nextDistribution;
        while (next < rewardDistributions.length) {
            RewardTokenDistribution storage d = rewardDistributions[next];
            next++;

            uint256 sh = rb.shares[d.poolToken];
            if (sh == 0) continue;
            uint256 distrAmount = d.amounts[rewardToken];
            balance = balance.add(distrAmount.mul(sh).div(d.totalShares));
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

    function distributeReward(address _protocol) internal {
        (address[] memory _tokens, uint256[] memory _amounts) = IDefiProtocol(_protocol).claimRewards();
        if(_tokens.length > 0) {
            address poolToken = poolTokenByProtocol(_protocol);
            distributeReward(poolToken, _tokens, _amounts);
        }
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
        for(uint256 i = 0; i < rewardTokens.length; i++) {
            rd.amounts[rewardTokens[i]] = amounts[i];  
            emit RewardDistribution(poolToken, rewardTokens[i], amounts[i], rd.totalShares);
        }
    }

    function _withdrawReward(address user, address rewardToken) internal returns(uint256) {
        address[] memory poolTokens = registeredPoolTokens();
        uint256 totalAmount;
        for(uint256 i=0; i < poolTokens.length; i++) {
            address poolToken = poolTokens[i];
            uint256 amount = rewardBalances[user].rewardsByProtocol[poolToken].amounts[rewardToken];
            if(amount > 0){
                totalAmount = totalAmount.add(amount);
                rewardBalances[user].rewardsByProtocol[poolToken].amounts[rewardToken] = 0;
                IDefiProtocol protocol = IDefiProtocol(protocolByPoolToken(poolToken));
                protocol.withdrawReward(rewardToken, user, amount);
            }
        }
        require(totalAmount > 0, "RewardDistributions: nothing to withdraw");
        emit RewardWithdraw(user, rewardToken, totalAmount);
        return totalAmount;
    }

    function _withdrawReward(address user, address poolToken, address rewardToken) internal returns(uint256) {
        uint256 amount = rewardBalances[user].rewardsByProtocol[poolToken].amounts[rewardToken];
        require(amount > 0, "RewardDistributions: nothing to withdraw");
        rewardBalances[user].rewardsByProtocol[poolToken].amounts[rewardToken] = 0;
        IDefiProtocol protocol = IDefiProtocol(protocolByPoolToken(poolToken));
        protocol.withdrawReward(rewardToken, user, amount);
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
            next++;
            uint256 sh = rb.shares[d.poolToken];
            if (sh == 0) continue;
            UserProtocolRewards storage upr = rb.rewardsByProtocol[d.poolToken]; 
            for (uint256 i=0; i < d.rewardTokens.length; i++) {
                address rToken = d.rewardTokens[i];
                uint256 distrAmount = d.amounts[rToken];
                upr.amounts[rToken] = upr.amounts[rToken].add(distrAmount.mul(sh).div(d.totalShares));

            }
        }
        rb.nextDistribution = next;
    }

    function isPoolToken(address token) internal view returns(bool);
}