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


    modifier onlyRewardDistributionModule() {
        require(_msgSender() == getModuleAddress(MODULE_REWARD_DISTR), "StakingPool: calls allowed from RewardDistributionModule only");
        _;
    }

    function setRewardVesting(address _rewardVesting) external onlyOwner {
        rewardVesting = RewardVestingModule(_rewardVesting);
    }

    function registerRewardToken(address _token) external onlyOwner {
        require(!isRegisteredRewardToken(_token), "StakingPool: already registered");
        registeredRewardTokens.push(_token);
        emit RewardTokenRegistered(_token);
    }

    function claimRewardsFromVesting() external onlyCapper{
        _claimRewardsFromVesting();
    }

    function isRegisteredRewardToken(address _token) public view returns(bool) {
        for(uint256 i=0; i<registeredRewardTokens.length; i++){
            if(_token == registeredRewardTokens[i]) return true;
        }
        return false;
    }

    function supportedRewardTokens() external view returns(address[] memory) {
        return registeredRewardTokens;
    }

    function withdrawRewards() external returns(uint256[] memory){
        return _withdrawRewards(_msgSender());
    }

    function withdrawRewardsFor(address user, address rewardToken) external onlyRewardDistributionModule returns(uint256) {
        return _withdrawRewards(user, rewardToken);
    }

    // function withdrawRewardsFor(address user, address[] memory rewardTokens) onlyRewardDistributionModule {
    //     for(uint256 i=0; i < rewardTokens.length; i++) {
    //         _withdrawRewards(user, rewardTokens[i]);
    //     }
    // }

    function rewardBalanceOf(address user, address _token) public view returns(uint256) {
        RewardData storage rd = rewards[_token];
        if(rd.unclaimed == 0) return 0; //Either token not registered or everything is already claimed
        uint256 shares = getPersonalStakeTotalAmount(user);
        if(shares == 0) return 0;
        UserRewardInfo storage uri = userRewards[user];
        uint256 reward;
        for(uint256 i=uri.nextDistribution[_token]; i < rd.distributions.length; i++) {
            RewardDistribution storage rdistr = rd.distributions[i];
            uint256 r = shares.mul(rdistr.amount).div(rdistr.totalShares);
            reward = reward.add(r);
        }
        return reward;
    }

    function _withdrawRewards(address user) internal returns(uint256[] memory rwrds) {
        rwrds = new uint256[](registeredRewardTokens.length);
        for(uint256 i=0; i<registeredRewardTokens.length; i++){
            rwrds[i] = _withdrawRewards(user, registeredRewardTokens[i]);
        }
        return rwrds;
    }

    function _withdrawRewards(address user, address _token) internal returns(uint256){
        UserRewardInfo storage uri = userRewards[user];
        RewardData storage rd = rewards[_token];
        if(rd.distributions.length == 0) { //No distributions = nothing to do
            return 0;
        }
        uint256 rwrds = rewardBalanceOf(user, _token);
        uri.nextDistribution[_token] = rd.distributions.length;
        if(rwrds > 0){
            rewards[_token].unclaimed = rewards[_token].unclaimed.sub(rwrds);
            IERC20(_token).transfer(user, rwrds);
            emit RewardWithdraw(user, _token, rwrds);
        }
        return rwrds;
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
