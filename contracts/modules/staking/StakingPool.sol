pragma solidity ^0.5.12; 

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "../reward/RewardVestingModule.sol";
import "./StakingPoolBase.sol";

contract StakingPool is StakingPoolBase {
    event RewardTokenRegistered(address token);
    event RewardDistributionCreated(address token, uint256 amount, uint256 totalShares);
    event RewardWithdraw(address indexed user, address indexed rewardToken, uint256 amount);

    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    struct RewardDistribution {
        uint256 totalShares;
        uint256 amount;
    }

    struct UserRewardInfo {
        mapping(address=>uint256) nextDistribution; //Next unclaimed distribution
    }

    struct RewardData {
        RewardDistribution[] distributions;
        uint256 unclaimed;
    }

    RewardVestingModule public rewardVesting;
    address[] internal registeredRewardTokens;
    mapping(address=>RewardData) internal rewards;
    mapping(address=>UserRewardInfo) internal userRewards;


    function registerRewardToken(address token) public onlyOwner {
        require(!isRegisteredRewardToken(token), "StakingPool: already registered");
        registeredRewardTokens.push(token);
        emit RewardTokenRegistered(token);
    }

    function isRegisteredRewardToken(address token) public view returns(bool) {
        for(uint256 i=0; i<registeredRewardTokens.length; i++){
            if(token == registeredRewardTokens[i]) return true;
        }
        return false;
    }

    function supportedRewardTokens() public view returns(address[] memory) {
        return registeredRewardTokens;
    }

    function withdrawRewards() public {
        _withdrawRewards(_msgSender());
    }

    function rewardBalanceOf(address user, address token) public view returns(uint256) {
        RewardData storage rd = rewards[token];
        if(rd.unclaimed == 0) return 0; //Either token not registered or everything is already claimed
        uint256 shares = getPersonalStakeTotalAmount(user);
        if(shares == 0) return 0;
        UserRewardInfo storage uri = userRewards[user];
        uint256 reward;
        for(uint256 i=uri.nextDistribution[token]; i < rd.distributions.length; i++) {
            RewardDistribution storage rdistr = rd.distributions[i];
            uint256 r = shares.mul(rdistr.amount).div(rdistr.totalShares);
            reward = reward.add(r);
        }
        return reward;
    }

    function _withdrawRewards(address user) internal {
        for(uint256 i=0; i<registeredRewardTokens.length; i++){
            _withdrawRewards(user, registeredRewardTokens[i]);
        }
    }

    function _withdrawRewards(address user, address token) internal {
        UserRewardInfo storage uri = userRewards[user];
        RewardData storage rd = rewards[token];
        if(rd.distributions.length == 0) { //No distributions = nothing to do
            return;
        }
        uint256 rwrds = rewardBalanceOf(user, token);
        uri.nextDistribution[token] = rd.distributions.length;
        if(rwrds > 0){
            rewards[token].unclaimed = rewards[token].unclaimed.sub(rwrds);
            IERC20(token).transfer(user, rwrds);
            emit RewardWithdraw(user, token, rwrds);
        }
    }

    function createStake(address _address, uint256 _amount, uint256 _lockInDuration, bytes memory _data) internal {
        _withdrawRewards(_address);
        super.createStake(_address, _amount, _lockInDuration, _data);
    }

    function withdrawStake(uint256 _amount, bytes memory _data) internal {
        _withdrawRewards(_msgSender());
        super.withdrawStake(_amount, _data);
    }


    function _claimRewardsFromVesting() internal {
        rewardVesting.claimRewards();
        for(uint256 i=0; i < registeredRewardTokens.length; i++){
            address rt = registeredRewardTokens[i];
            uint256 expectedBalance = rewards[rt].unclaimed;
            if(rt == address(stakingToken)){
                expectedBalance = expectedBalance.add(totalStaked());
            }
            uint256 actualBalance = IERC20(rt).balanceOf(address(this));
            uint256 distributionAmount = actualBalance.sub(expectedBalance);
            if(actualBalance > expectedBalance) {
                uint256 totalShares = totalStaked();
                rewards[rt].distributions.push(RewardDistribution({
                    totalShares: totalShares,
                    amount: distributionAmount
                }));
                rewards[rt].unclaimed = rewards[rt].unclaimed.add(distributionAmount);
                emit RewardDistributionCreated(rt, distributionAmount, totalShares);
            }
        }
    }

}
