pragma solidity ^0.5.12;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "../../common/Base.sol";
import "../../interfaces/token/IPoolTokenBalanceChangeRecipient.sol";
import "../../interfaces/defi/IDefiProtocol.sol";
import "../access/AccessChecker.sol";
import "../savings/SavingsModule.sol";
import "../staking/StakingPool.sol";
import "../token/PoolToken.sol";

contract RewardDistributionModule is Module, IPoolTokenBalanceChangeRecipient, AccessChecker {
    uint256 public constant DISTRIBUTION_AGGREGATION_PERIOD = 24*60*60;

    event ProtocolRegistered(address protocol, address poolToken);
    event RewardDistribution(address indexed poolToken, address indexed rewardToken, uint256 amount, uint256 totalShares);
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
        uint256 shares;
        mapping(address=>uint256) amounts;  // Maps address of reward token to amount beeing distributed
    }
    struct RewardBalance {
        uint256 nextDistribution;
        mapping(address => UserProtocolRewards) rewardsByPT; //Maps PoolToken to ProtocolRewards struct (map of reward tokens to their balances);
    }

    struct ProtocolInfo {
        address poolToken;
        uint256 lastRewardDistributionTimestamp;
        address[] rewardTokens;
    }

    RewardTokenDistribution[] rewardDistributions;
    mapping(address=>RewardBalance) rewardBalances; //Mapping users to their RewardBalance

    address[] internal registeredRewardTokens;
    address[] internal registeredPoolTokens;
    mapping(address=>bool) public isRewardToken;
    mapping(address=>address) internal poolTokenToProtocol;
    mapping(address=>ProtocolInfo) public protocolInfo;
    mapping(address=>bool) public userRewardsMigrated;


    function initialize(address _pool) public initializer {
        Module.initialize(_pool);
    }

    function registerProtocol(address _protocol, address _poolToken) public onlyOwner {
        require(protocolInfo[_protocol].poolToken == address(0), "RewardDistributionModule: protocol already registered");
        require(poolTokenToProtocol[_poolToken] == address(0), "RewardDistributionModule: poolToken already registered");

        registeredPoolTokens.push(_poolToken);
        poolTokenToProtocol[_poolToken] = _protocol;

        address[] memory rTokens = IDefiProtocol(_protocol).supportedRewardTokens();

        protocolInfo[_protocol] = ProtocolInfo({
            poolToken: _poolToken,
            lastRewardDistributionTimestamp: 0,
            rewardTokens: rTokens
        });

        for(uint256 i=0; i < rTokens.length; i++) {
            if(!isRewardToken[rTokens[i]]){
                isRewardToken[rTokens[i]] = true;
                registeredRewardTokens.push(rTokens[i]);
            }
        }

        emit ProtocolRegistered(_protocol, _poolToken);
    }    


    function poolTokenByProtocol(address _protocol) public view returns(address) {
        return protocolInfo[_protocol].poolToken;
    }
    function protocolByPoolToken(address _poolToken) public view returns(address)  {
        return poolTokenToProtocol[_poolToken];
    }
    function supportedPoolTokens() public view returns(address[] memory) {
        return registeredPoolTokens;
    }
    function supportedRewardTokens() public view returns(address[] memory) {
        return registeredRewardTokens;
    }

    function poolTokenBalanceChanged(address user) public {
        address token = _msgSender();
        require(isPoolToken(token), "RewardDistributionModule: PoolToken is not registered");

        _updateRewardBalance(user, rewardDistributions.length);
        uint256 newAmount = PoolToken(token).distributionBalanceOf(user);
        rewardBalances[user].rewardsByPT[token].shares = newAmount;
    }

    /** 
     * @notice Distributes reward tokens. May be called by bot, if there was no deposits/withdrawals
     */
    function distributeRewards() public {
        for(uint256 i=0; i<registeredPoolTokens.length; i++) {
            distributeRewardIfRequired(poolTokenToProtocol[registeredPoolTokens[i]]);
        }
    }

    // function distributeRewards(address _protocol) public {
    //     distributeRewardIfRequired(_protocol);
    // }

    function distributeRewardsForced(address _protocol) public onlyOwner {
        protocolInfo[_protocol].lastRewardDistributionTimestamp = now;
        distributeReward(_protocol);
    }

    function distributeRewardIfRequired(address _protocol) internal {
        if(!isRewardDistributionRequired(_protocol)) return;
        protocolInfo[_protocol].lastRewardDistributionTimestamp = now;
        distributeReward(_protocol);
    }

    function isRewardDistributionRequired(address _protocol) internal view returns(bool) {
        uint256 lrd = protocolInfo[_protocol].lastRewardDistributionTimestamp;
        return now.sub(lrd) > DISTRIBUTION_AGGREGATION_PERIOD;
    }

    function withdrawReward() public returns(uint256[] memory) {
        return withdrawReward(supportedRewardTokens());
    }

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

    function withdrawReward(address poolToken, address rewardToken) 
    public operationAllowed(IAccessModule.Operation.Withdraw)
    returns(uint256){
        address user = _msgSender();
        updateRewardBalance(user);
        return _withdrawReward(user, poolToken, rewardToken);
    }

    function withdrawReward(address[] memory poolTokens, address[] memory rewardTokens) 
    public operationAllowed(IAccessModule.Operation.Withdraw)
    returns(uint256[] memory){
        require(poolTokens.length == rewardTokens.length, "RewardDistributionModule: array length mismatch");

        address akroStaking = getModuleAddress(MODULE_STAKING_AKRO);
        address adelStaking = getModuleAddress(MODULE_STAKING_ADEL);

        uint256[] memory amounts = new uint256[](poolTokens.length);
        address user = _msgSender();
        updateRewardBalance(user);
        for(uint256 i=0; i < poolTokens.length; i++) {
            if(poolTokens[i] == akroStaking || poolTokens[i] == adelStaking){
                amounts[i] = StakingPool(poolTokens[i]).withdrawRewardsFor(user, rewardTokens[i]);
            }else{
                amounts[i] = _withdrawReward(user, poolTokens[i], rewardTokens[i]);
            }
        }
        return amounts;
    }

    // function rewardBalanceOf(address user, address[] memory rewardTokens) public view returns(uint256[] memory) {
    //     uint256[] memory amounts = new uint256[](rewardTokens.length);
    //     address[] memory poolTokens = registeredPoolTokens();
    //     for(uint256 i=0; i < rewardTokens.length; i++) {
    //         for(uint256 j=0; j < poolTokens.length; j++) {
    //             amounts[i] = amounts[i].add(rewardBalanceOf(user, poolTokens[j], rewardTokens[i]));
    //         }
    //     }
    //     return amounts;
    // }


    function rewardBalanceOf(address user, address poolToken, address rewardToken) public view returns(uint256 amounts) {
        if(!userRewardsMigrated[user]){
            address[] memory rtkns = new address[](1);
            rtkns[0] = rewardToken;
            return savingsModule().rewardBalanceOf(user, poolToken, rtkns)[0];
        }

        RewardBalance storage rb = rewardBalances[user];
        UserProtocolRewards storage upr = rb.rewardsByPT[poolToken];
        uint256 balance = upr.amounts[rewardToken];
        uint256 next = rb.nextDistribution;
        while (next < rewardDistributions.length) {
            RewardTokenDistribution storage d = rewardDistributions[next];
            next++;

            uint256 sh = rb.rewardsByPT[d.poolToken].shares;
            if (sh == 0 || poolToken != d.poolToken) continue;
            uint256 distrAmount = d.amounts[rewardToken];
            balance = balance.add(distrAmount.mul(sh).div(d.totalShares));
        }
        return balance;
    }

    function rewardBalanceOf(address user, address poolToken, address[] calldata rewardTokens) external view returns(uint256[] memory) {
        if(!userRewardsMigrated[user]) return savingsModule().rewardBalanceOf(user, poolToken, rewardTokens);

        RewardBalance storage rb = rewardBalances[user];
        UserProtocolRewards storage upr = rb.rewardsByPT[poolToken];
        uint256[] memory balances = new uint256[](rewardTokens.length);
        uint256 i;
        for(i=0; i < rewardTokens.length; i++){
            balances[i] = upr.amounts[rewardTokens[i]];
        }
        uint256 next = rb.nextDistribution;
        while (next < rewardDistributions.length) {
            RewardTokenDistribution storage d = rewardDistributions[next];
            next++;

            uint256 sh = rb.rewardsByPT[d.poolToken].shares;
            if (sh == 0 || poolToken != d.poolToken) continue;
            for(i=0; i < rewardTokens.length; i++){
                uint256 distrAmount = d.amounts[rewardTokens[i]];
                balances[i] = balances[i].add(distrAmount.mul(sh).div(d.totalShares));
            }
        }
        return balances;
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

    function storedRewardBalance(address user, address poolToken, address rewardToken) public view 
    returns(uint256 nextDistribution, uint256 poolTokenShares, uint256 storedReward) {
        RewardBalance storage rb = rewardBalances[user];
        nextDistribution = rb.nextDistribution;
        poolTokenShares = rb.rewardsByPT[poolToken].shares;
        storedReward = rb.rewardsByPT[poolToken].amounts[rewardToken];
    }

    function rewardDistribution(uint256 num) public view 
    returns(address poolToken, uint256 totalShares, address[] memory rewardTokens, uint256[] memory amounts){
        RewardTokenDistribution storage d = rewardDistributions[num];
        poolToken = d.poolToken;
        totalShares = d.totalShares;
        rewardTokens = d.rewardTokens;
        amounts = new uint256[](rewardTokens.length);
        for(uint256 i=0; i < rewardTokens.length; i++) {
            address tkn = rewardTokens[i];
            amounts[i] = d.amounts[tkn];
        }
    }

    function rewardDistributionCount() public view returns(uint256){
        return rewardDistributions.length;
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

    function migrateRewards(address[] calldata users) external {
        for(uint256 i=0; i<users.length;i++){
            migrateUserRewards(users[i]);
        }
    }

    function migrateUserRewards(address user) internal {
        if(userRewardsMigrated[user]) return; //Skip already migrated
        RewardBalance storage rb =rewardBalances[user];

        SavingsModule sm = savingsModule();
        IDefiProtocol[] memory protocols = sm.supportedProtocols();
        for(uint256 i=0; i<protocols.length; i++) {
            address _protocol = address(protocols[i]);
            address _poolToken = protocolInfo[_protocol].poolToken;
            UserProtocolRewards storage upr = rb.rewardsByPT[_poolToken];
            upr.shares = PoolToken(_poolToken).distributionBalanceOf(user);
            address[] memory rtkns = sm.rewardTokensByProtocol(_protocol);
            uint256[] memory balances = sm.rewardBalanceOf(user, _poolToken, rtkns);
            for(uint256 j=0; j<rtkns.length; j++){
                upr.amounts[rtkns[j]] = balances[j];
            }
        }
        userRewardsMigrated[user] = true;
    }

    function _withdrawReward(address user, address rewardToken) internal returns(uint256) {
        uint256 totalAmount;
        for(uint256 i=0; i < registeredPoolTokens.length; i++) {
            address poolToken = registeredPoolTokens[i];
            uint256 amount = rewardBalances[user].rewardsByPT[poolToken].amounts[rewardToken];
            if(amount > 0){
                totalAmount = totalAmount.add(amount);
                rewardBalances[user].rewardsByPT[poolToken].amounts[rewardToken] = 0;
                IDefiProtocol protocol = IDefiProtocol(protocolByPoolToken(poolToken));
                protocol.withdrawReward(rewardToken, user, amount);
            }
        }
        if(totalAmount > 0) {
            emit RewardWithdraw(user, rewardToken, totalAmount);
        }
        return totalAmount;
    }

    function _withdrawReward(address user, address poolToken, address rewardToken) internal returns(uint256) {
        uint256 amount = rewardBalances[user].rewardsByPT[poolToken].amounts[rewardToken];
        require(amount > 0, "RewardDistributionModule: nothing to withdraw");
        rewardBalances[user].rewardsByPT[poolToken].amounts[rewardToken] = 0;
        IDefiProtocol protocol = IDefiProtocol(protocolByPoolToken(poolToken));
        protocol.withdrawReward(rewardToken, user, amount);
        emit RewardWithdraw(user, rewardToken, amount);
        return amount;
    }

    function _updateRewardBalance(address user, uint256 toDistribution) internal {
        require(toDistribution <= rewardDistributions.length, "RewardDistributionModule: toDistribution index is too high");
        if(!userRewardsMigrated[user]) migrateUserRewards(user);

        RewardBalance storage rb = rewardBalances[user];
        uint256 next = rb.nextDistribution;
        if(next >= toDistribution) return;

        if(next == 0 && rewardDistributions.length > 0){
            //This might be a new user, if so we can skip previous distributions
            bool hasDeposit;
            for(uint256 i=0; i< registeredPoolTokens.length; i++){
                address poolToken = registeredPoolTokens[i];
                if(rb.rewardsByPT[poolToken].shares != 0) {
                    hasDeposit = true;
                    break;
                }
            }
            if(!hasDeposit){
                rb.nextDistribution = rewardDistributions.length;
                return;
            }
        }

        while (next < toDistribution) {
            RewardTokenDistribution storage d = rewardDistributions[next];
            next++;
            UserProtocolRewards storage upr = rb.rewardsByPT[d.poolToken]; 
            uint256 sh = upr.shares;
            if (sh == 0) continue;
            for (uint256 i=0; i < d.rewardTokens.length; i++) {
                address rToken = d.rewardTokens[i];
                uint256 distrAmount = d.amounts[rToken];
                upr.amounts[rToken] = upr.amounts[rToken].add(distrAmount.mul(sh).div(d.totalShares));

            }
        }
        rb.nextDistribution = next;
    }

    function savingsModule() internal view returns (SavingsModule) {
        return SavingsModule(getModuleAddress(MODULE_SAVINGS));
    }

    function isPoolToken(address _token) internal view returns(bool) {
        return (poolTokenToProtocol[_token] != address(0));
    }
}