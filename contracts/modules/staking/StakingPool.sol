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

    address public swapContract;


    modifier onlyRewardDistributionModule() {
        require(_msgSender() == getModuleAddress(MODULE_REWARD_DISTR), "StakingPool: calls allowed from RewardDistributionModule only");
        _;
    }

    function setRewardVesting(address _rewardVesting) public onlyOwner {
        rewardVesting = RewardVestingModule(_rewardVesting);
    }

    function registerRewardToken(address token) public onlyOwner {
        require(!isRegisteredRewardToken(token), "StakingPool: already registered");
        registeredRewardTokens.push(token);
        emit RewardTokenRegistered(token);
    }

    function claimRewardsFromVesting() public onlyCapper{
        _claimRewardsFromVesting();
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

    function withdrawRewards() public returns(uint256[] memory){
        return _withdrawRewards(_msgSender());
    }

    function withdrawRewardsFor(address user, address rewardToken) public onlyRewardDistributionModule returns(uint256) {
        return _withdrawRewards(user, rewardToken);
    }

    // function withdrawRewardsFor(address user, address[] memory rewardTokens) onlyRewardDistributionModule {
    //     for(uint256 i=0; i < rewardTokens.length; i++) {
    //         _withdrawRewards(user, rewardTokens[i]);
    //     }
    // }

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

    function _withdrawRewards(address user) internal returns(uint256[] memory rwrds) {
        rwrds = new uint256[](registeredRewardTokens.length);
        for(uint256 i=0; i<registeredRewardTokens.length; i++){
            rwrds[i] = _withdrawRewards(user, registeredRewardTokens[i]);
        }
        return rwrds;
    }

    function _withdrawRewards(address user, address token) internal returns(uint256){
        UserRewardInfo storage uri = userRewards[user];
        RewardData storage rd = rewards[token];
        if(rd.distributions.length == 0) { //No distributions = nothing to do
            return 0;
        }
        uint256 rwrds = rewardBalanceOf(user, token);
        uri.nextDistribution[token] = rd.distributions.length;
        if(rwrds > 0){
            rewards[token].unclaimed = rewards[token].unclaimed.sub(rwrds);
            IERC20(token).transfer(user, rwrds);
            emit RewardWithdraw(user, token, rwrds);
        }
        return rwrds;
    }

    function createStake(address _address, uint256 _amount, uint256 _lockInDuration, bytes memory _data) internal {
        _withdrawRewards(_address);
        super.createStake(_address, _amount, _lockInDuration, _data);
    }

    function unstake(uint256 _amount, bytes memory _data) public {
        _withdrawRewards(_msgSender());
        withdrawStake(_amount, _data);
    }

    function unstakeAllUnlocked(bytes memory _data) public returns (uint256) {
        _withdrawRewards(_msgSender());
        return super.unstakeAllUnlocked(_data);
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

    modifier swapEligible(address _user) {
        require(swapContract != address(0), "Swap is disabled");
        require(_msgSender() == swapContract, "Caller is not a swap contract");
        require(_user != address(0), "Zero address");
        _;
    }

    /**
     * @notice Admin function to set the address of the ADEL/vAkro Swap contract
     * @notice Default value is 0-address, which means, that swap is disabled 
     * @param _swapContract Adel to vAkro Swap contract.
     */
    function setSwapContract(address _swapContract) external onlyOwner {
        swapContract = _swapContract;
    }

    /**
     * @notice Function which is alternative to "unstake" the ADEL token.
     * @notice Though, instead of withdrawing the ADEL, the function sends it to the Swap contract.
     * @notice Can be called ONLY by the Swap contract.
     * @param _user User to withdraw the stake for.
     * @param _token Adel address.
     * @param _data Data for the event.
     */
    function withdrawStakeForSwap(address _user, address _token, bytes calldata _data)
            external
            swapEligible(_user)
            returns(uint256)
    {
        uint256 returnValue = 0;
        for(uint256 i = 0; i < registeredRewardTokens.length; i++) {
            uint256 rwrds = withdrawRewardForSwap(_user, registeredRewardTokens[i]);
            if (_token == registeredRewardTokens[i]) {
                returnValue += rwrds;
            }
        }
        return returnValue + super.withdrawStakes(_msgSender(), _user, _data);
    }

    /**
     * @notice Function which is alternative to "claiming" ADEL rewards.
     * @notice Though, instead of claiming the ADEL, the function sends it to the Swap contract.
     * @notice Can be called ONLY by the Swap contract.
     * @param _user User to withdraw the stake for.
     * @param _token Token to get the rewards (can be only ADEL).
     */
    function withdrawRewardForSwap(address _user, address _token) public swapEligible(_user) 
        returns(uint256)
    {
        UserRewardInfo storage uri = userRewards[_user];
        RewardData storage rd = rewards[_token];

        require(rd.distributions.length > 0, "No distributions"); //No distributions = nothing to do

        uint256 rwrds = rewardBalanceOf(_user, _token);

        if (rwrds == 0) {
            return 0;
        }

        uri.nextDistribution[_token] = rd.distributions.length;

        rewards[_token].unclaimed = rewards[_token].unclaimed.sub(rwrds);

        IERC20(_token).transfer(swapContract, rwrds);

        emit RewardWithdraw(_user, _token, rwrds);
        return rwrds;
    }
}
