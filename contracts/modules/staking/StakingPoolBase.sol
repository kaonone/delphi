pragma solidity ^0.5.12;

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";

import "./IERC900.sol";
import "../../common/Module.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/roles/CapperRole.sol";

/**
 * @title ERC900 Simple Staking Interface basic implementation
 * @dev See https://github.com/ethereum/EIPs/blob/master/EIPS/eip-900.md
 */
contract StakingPoolBase is Module, IERC900, CapperRole  {
  // @TODO: deploy this separately so we don't have to deploy it multiple times for each contract
  using SafeMath for uint256;

  // Token used for staking
  ERC20 stakingToken;

  // The default duration of stake lock-in (in seconds)
  uint256 public defaultLockInDuration;

  // To save on gas, rather than create a separate mapping for totalStakedFor & personalStakes,
  //  both data structures are stored in a single mapping for a given addresses.
  //
  // It's possible to have a non-existing personalStakes, but have tokens in totalStakedFor
  //  if other users are staking on behalf of a given address.
  mapping (address => StakeContract) public stakeHolders;

  // Struct for personal stakes (i.e., stakes made by this address)
  // unlockedTimestamp - when the stake unlocks (in seconds since Unix epoch)
  // actualAmount - the amount of tokens in the stake
  // stakedFor - the address the stake was staked for
  struct Stake {
    uint256 unlockedTimestamp;
    uint256 actualAmount;
    address stakedFor;
  }

  // Struct for all stake metadata at a particular address
  // totalStakedFor - the number of tokens staked for this address
  // personalStakeIndex - the index in the personalStakes array.
  // personalStakes - append only array of stakes made by this address
  // exists - whether or not there are stakes that involve this address
  struct StakeContract {
    uint256 totalStakedFor;

    uint256 personalStakeIndex;

    Stake[] personalStakes;

    bool exists;
  }

  bool public userCapEnabled;

  mapping(address => uint256) public userCap; //Limit of pool tokens which can be minted for a user during deposit

  
  uint256 public defaultUserCap;
  bool public stakingCapEnabled;
  uint256 public stakingCap;


  bool public vipUserEnabled;
  mapping(address => bool) public isVipUser;

  uint256 internal totalStakedAmount;

  uint256 public coeffScore;
  


  event VipUserEnabledChange(bool enabled);
  event VipUserChanged(address indexed user, bool isVip);

  event StakingCapChanged(uint256 newCap);
  event StakingCapEnabledChange(bool enabled);

  //global cap
  event DefaultUserCapChanged(uint256 newCap);

  event UserCapEnabledChange(bool enabled);

  event UserCapChanged(address indexed user, uint256 newCap);
  event Staked(address indexed user, uint256 amount, uint256 totalStacked, bytes data);
  event Unstaked(address indexed user, uint256 amount, uint256 totalStacked, bytes data);
  event setLockInDuration(uint256 defaultLockInDuration);

  event CoeffScoreUpdated(uint256 coeff);
  /**
   * @dev Modifier that checks that this contract can transfer tokens from the
   *  balance in the stakingToken contract for the given address.
   * @dev This modifier also transfers the tokens.
   * @param _address address to transfer tokens from
   * @param _amount uint256 the number of tokens
   */
  modifier canStake(address _address, uint256 _amount) {
    require(
      stakingToken.transferFrom(_address, address(this), _amount),
      "Stake required");

    _;
  }


  modifier isUserCapEnabledForStakeFor(uint256 stake) {

    if (stakingCapEnabled && !(vipUserEnabled && isVipUser[_msgSender()])) {
        require((stakingCap > totalStaked() && (stakingCap-totalStaked() >= stake)), "StakingModule: stake exeeds staking cap");
    }

    if(userCapEnabled) {
          uint256 cap = userCap[_msgSender()];
          //check default user cap settings
          if (defaultUserCap > 0) {
              uint256 totalStaked = totalStakedFor(_msgSender());
              //get new cap
              if (defaultUserCap >= totalStaked) {
                cap = defaultUserCap.sub(totalStaked);
              } else {
                 cap = 0;
              }
          }
          
          require(cap >= stake, "StakingModule: stake exeeds cap");
          cap = cap.sub(stake);
          userCap[_msgSender()] = cap;
          emit UserCapChanged(_msgSender(), cap);  
    }
      
    _;
  }


  modifier isUserCapEnabledForUnStakeFor(uint256 unStake) {
     _;
     checkAndUpdateCapForUnstakeFor(unStake);
  }
  function checkAndUpdateCapForUnstakeFor(uint256 unStake) internal {
     if(userCapEnabled){
        uint256 cap = userCap[_msgSender()];
        cap = cap.add(unStake);

        if (cap > defaultUserCap) {
            cap = defaultUserCap;
        }

        userCap[_msgSender()] = cap;
        emit UserCapChanged(_msgSender(), cap);
     }
  }


  modifier checkUserCapDisabled() {
    require(isUserCapEnabled() == false, "UserCapEnabled");
    _;
  }

  modifier checkUserCapEnabled() {
    require(isUserCapEnabled(), "UserCapDisabled");
    _;
  }
 

  function initialize(address _pool, ERC20 _stakingToken, uint256 _defaultLockInDuration) public initializer {
        stakingToken = _stakingToken;
        defaultLockInDuration = _defaultLockInDuration;
        Module.initialize(_pool);

        CapperRole.initialize(_msgSender());
  }

  function setDefaultLockInDuration(uint256 _defaultLockInDuration) public onlyOwner {
      defaultLockInDuration = _defaultLockInDuration;
      emit setLockInDuration(_defaultLockInDuration);
  }

  function setUserCapEnabled(bool _userCapEnabled) public onlyCapper {
      userCapEnabled = _userCapEnabled;
      emit UserCapEnabledChange(userCapEnabled);
  }

  function setStakingCapEnabled(bool _stakingCapEnabled) public onlyCapper {
      stakingCapEnabled= _stakingCapEnabled;
      emit StakingCapEnabledChange(stakingCapEnabled);
  }

  function setDefaultUserCap(uint256 _newCap) public onlyCapper {
      defaultUserCap = _newCap;
      emit DefaultUserCapChanged(_newCap);
  }

  function setStakingCap(uint256 _newCap) public onlyCapper {
      stakingCap = _newCap;
      emit StakingCapChanged(_newCap);
  }

  function setUserCap(address user, uint256 cap) public onlyCapper {
      userCap[user] = cap;
      emit UserCapChanged(user, cap);
  }

  function setUserCap(address[] memory users, uint256[] memory caps) public onlyCapper {
        require(users.length == caps.length, "SavingsModule: arrays length not match");
        for(uint256 i=0;  i < users.length; i++) {
            userCap[users[i]] = caps[i];
            emit UserCapChanged(users[i], caps[i]);
        }

  }

  function setVipUserEnabled(bool _vipUserEnabled) public onlyCapper {
      vipUserEnabled = _vipUserEnabled;
      emit VipUserEnabledChange(_vipUserEnabled);
  }

  function setVipUser(address user, bool isVip) public onlyCapper {
      isVipUser[user] = isVip;
      emit VipUserChanged(user, isVip);
  }

  function setCoeffScore(uint256 coeff) public onlyCapper {
    coeffScore = coeff;

    emit CoeffScoreUpdated(coeff);
  }

  function isUserCapEnabled() public view returns(bool) {
    return userCapEnabled;
  }

  function iStakingCapEnabled() public view returns(bool) {
    return stakingCapEnabled;
  }

  /**
   * @dev Returns the timestamps for when active personal stakes for an address will unlock
   * @dev These accessors functions are needed until https://github.com/ethereum/web3.js/issues/1241 is solved
   * @param _address address that created the stakes
   * @return uint256[] array of timestamps
   */
  function getPersonalStakeUnlockedTimestamps(address _address) external view returns (uint256[] memory) {
    uint256[] memory timestamps;
    (timestamps,,) = getPersonalStakes(_address);

    return timestamps;
  }

  /**
   * @dev Returns the stake actualAmount for active personal stakes for an address
   * @dev These accessors functions are needed until https://github.com/ethereum/web3.js/issues/1241 is solved
   * @param _address address that created the stakes
   * @return uint256[] array of actualAmounts
   */
  function getPersonalStakeActualAmounts(address _address) external view returns (uint256[] memory) {
    uint256[] memory actualAmounts;
    (,actualAmounts,) = getPersonalStakes(_address);

    return actualAmounts;
  }

  function getPersonalStakeTotalAmount(address _address) public view returns(uint256) {
    uint256[] memory actualAmounts;
    (,actualAmounts,) = getPersonalStakes(_address);
    uint256 totalStake;
    for(uint256 i=0; i <actualAmounts.length; i++) {
      totalStake = totalStake.add(actualAmounts[i]);
    }
    return totalStake;
  }

  /**
   * @dev Returns the addresses that each personal stake was created for by an address
   * @dev These accessors functions are needed until https://github.com/ethereum/web3.js/issues/1241 is solved
   * @param _address address that created the stakes
   * @return address[] array of amounts
   */
  function getPersonalStakeForAddresses(address _address) external view returns (address[] memory) {
    address[] memory stakedFor;
    (,,stakedFor) = getPersonalStakes(_address);

    return stakedFor;
  }

  /**
   * @notice Stakes a certain amount of tokens, this MUST transfer the given amount from the user
   * @notice MUST trigger Staked event
   * @param _amount uint256 the amount of tokens to stake
   * @param _data bytes optional data to include in the Stake event
   */
  function stake(uint256 _amount, bytes memory _data) public isUserCapEnabledForStakeFor(_amount) {
    createStake(
      _msgSender(),
      _amount,
      defaultLockInDuration,
      _data);
  }

  /**
   * @notice Stakes a certain amount of tokens, this MUST transfer the given amount from the caller
   * @notice MUST trigger Staked event
   * @param _user address the address the tokens are staked for
   * @param _amount uint256 the amount of tokens to stake
   * @param _data bytes optional data to include in the Stake event
   */
  function stakeFor(address _user, uint256 _amount, bytes memory _data) public checkUserCapDisabled {
    createStake(
      _user,
      _amount,
      defaultLockInDuration,
      _data);
  }

  /**
   * @notice Unstakes a certain amount of tokens, this SHOULD return the given amount of tokens to the user, if unstaking is currently not possible the function MUST revert
   * @notice MUST trigger Unstaked event
   * @dev Unstaking tokens is an atomic operation—either all of the tokens in a stake, or none of the tokens.
   * @dev Users can only unstake a single stake at a time, it is must be their oldest active stake. Upon releasing that stake, the tokens will be
   *  transferred back to their account, and their personalStakeIndex will increment to the next active stake.
   * @param _amount uint256 the amount of tokens to unstake
   * @param _data bytes optional data to include in the Unstake event
   */
  function unstake(uint256 _amount, bytes memory _data) public {
    withdrawStake(
      _amount,
      _data);
  }

  // function unstakeAllUnlocked(bytes memory _data) public returns (uint256) {
  //     uint256 unstakeAllAmount = 0;
  //     uint256 personalStakeIndex = stakeHolders[_msgSender()].personalStakeIndex;

  //     for (uint256 i = personalStakeIndex; i < stakeHolders[_msgSender()].personalStakes.length; i++) {
  //         if (stakeHolders[_msgSender()].personalStakes[i].unlockedTimestamp <= block.timestamp) {
  //             unstakeAllAmount = unstakeAllAmount.add(stakeHolders[_msgSender()].personalStakes[i].actualAmount);
  //             withdrawStake(stakeHolders[_msgSender()].personalStakes[i].actualAmount, _data);
  //         }
  //     }

  //     return unstakeAllAmount;
  // }

  function unstakeAllUnlocked(bytes memory _data) public returns (uint256) {
      return withdrawStakes(_msgSender(), _msgSender(), _data);
  }

  /**
   * @notice Returns the current total of tokens staked for an address
   * @param _address address The address to query
   * @return uint256 The number of tokens staked for the given address
   */
  function totalStakedFor(address _address) public view returns (uint256) {
    return stakeHolders[_address].totalStakedFor;
  }

  /**
   * @notice Returns the current total of tokens staked for an address
   * @param _address address The address to query
   * @return uint256 The number of tokens staked for the given address
   */
  function totalScoresFor(address _address) public view returns (uint256) {
    return stakeHolders[_address].totalStakedFor.mul(coeffScore).div(10**18);
  }

  /**
   * @notice Returns the current total of tokens staked
   * @return uint256 The number of tokens staked in the contract
   */
  function totalStaked() public view returns (uint256) {
    //return stakingToken.balanceOf(address(this));
    return totalStakedAmount;
  }

  /**
   * @notice Address of the token being used by the staking interface
   * @return address The address of the ERC20 token used for staking
   */
  function token() public view returns (address) {
    return address(stakingToken);
  }

  /**
   * @notice MUST return true if the optional history functions are implemented, otherwise false
   * @dev Since we don't implement the optional interface, this always returns false
   * @return bool Whether or not the optional history functions are implemented
   */
  function supportsHistory() public pure returns (bool) {
    return false;
  }

  /**
   * @dev Helper function to get specific properties of all of the personal stakes created by an address
   * @param _address address The address to query
   * @return (uint256[], uint256[], address[])
   *  timestamps array, actualAmounts array, stakedFor array
   */
  function getPersonalStakes(
    address _address
  )
    public view
    returns(uint256[] memory, uint256[] memory, address[] memory)
  {
    StakeContract storage stakeContract = stakeHolders[_address];

    uint256 arraySize = stakeContract.personalStakes.length - stakeContract.personalStakeIndex;
    uint256[] memory unlockedTimestamps = new uint256[](arraySize);
    uint256[] memory actualAmounts = new uint256[](arraySize);
    address[] memory stakedFor = new address[](arraySize);

    for (uint256 i = stakeContract.personalStakeIndex; i < stakeContract.personalStakes.length; i++) {
      uint256 index = i - stakeContract.personalStakeIndex;
      unlockedTimestamps[index] = stakeContract.personalStakes[i].unlockedTimestamp;
      actualAmounts[index] = stakeContract.personalStakes[i].actualAmount;
      stakedFor[index] = stakeContract.personalStakes[i].stakedFor;
    }

    return (
      unlockedTimestamps,
      actualAmounts,
      stakedFor
    );
  }

  /**
   * @dev Helper function to create stakes for a given address
   * @param _address address The address the stake is being created for
   * @param _amount uint256 The number of tokens being staked
   * @param _lockInDuration uint256 The duration to lock the tokens for
   * @param _data bytes optional data to include in the Stake event
   */
  function createStake(
    address _address,
    uint256 _amount,
    uint256 _lockInDuration,
    bytes memory _data)
    internal
    canStake(_msgSender(), _amount)
  {
    if (!stakeHolders[_msgSender()].exists) {
      stakeHolders[_msgSender()].exists = true;
    }

    stakeHolders[_address].totalStakedFor = stakeHolders[_address].totalStakedFor.add(_amount);
    stakeHolders[_msgSender()].personalStakes.push(
      Stake(
        block.timestamp.add(_lockInDuration),
        _amount,
        _address)
      );

    totalStakedAmount = totalStakedAmount.add(_amount);
    emit Staked(
      _address,
      _amount,
      totalStakedFor(_address),
      _data);
  }

  /**
   * @dev Helper function to withdraw stakes for the _msgSender()
   * @param _amount uint256 The amount to withdraw. MUST match the stake amount for the
   *  stake at personalStakeIndex.
   * @param _data bytes optional data to include in the Unstake event
   */
  function withdrawStake(
    uint256 _amount,
    bytes memory _data)
    internal isUserCapEnabledForUnStakeFor(_amount)
  {
    Stake storage personalStake = stakeHolders[_msgSender()].personalStakes[stakeHolders[_msgSender()].personalStakeIndex];

    // Check that the current stake has unlocked & matches the unstake amount
    require(
      personalStake.unlockedTimestamp <= block.timestamp,
      "The current stake hasn't unlocked yet");

    require(
      personalStake.actualAmount == _amount,
      "The unstake amount does not match the current stake");

    // Transfer the staked tokens from this contract back to the sender
    // Notice that we are using transfer instead of transferFrom here, so
    //  no approval is needed beforehand.
    require(
      stakingToken.transfer(_msgSender(), _amount),
      "Unable to withdraw stake");

    stakeHolders[personalStake.stakedFor].totalStakedFor = stakeHolders[personalStake.stakedFor]
      .totalStakedFor.sub(personalStake.actualAmount);

    personalStake.actualAmount = 0;
    stakeHolders[_msgSender()].personalStakeIndex++;

    totalStakedAmount = totalStakedAmount.sub(_amount);

    emit Unstaked(
      personalStake.stakedFor,
      _amount,
      totalStakedFor(personalStake.stakedFor),
      _data);
  }

  function withdrawStakes(address _transferTo, address _unstakeFor, bytes memory _data) internal returns (uint256){
      StakeContract storage sc = stakeHolders[_unstakeFor];
      uint256 unstakeAmount = 0;
      uint256 unstakedForOthers = 0;
      uint256 personalStakeIndex = sc.personalStakeIndex;

      uint256 i;
      for (i = personalStakeIndex; i < sc.personalStakes.length; i++) {
          Stake storage personalStake = sc.personalStakes[i];
          if(personalStake.unlockedTimestamp > block.timestamp) break; //We've found last unlocked stake
            
          if(personalStake.stakedFor != _unstakeFor){
              //Handle unstake of staked for other address
              stakeHolders[personalStake.stakedFor].totalStakedFor = stakeHolders[personalStake.stakedFor].totalStakedFor.sub(personalStake.actualAmount);
              unstakedForOthers = unstakedForOthers.add(personalStake.actualAmount);
              emit Unstaked(personalStake.stakedFor, personalStake.actualAmount, totalStakedFor(personalStake.stakedFor), _data);
          }

          unstakeAmount = unstakeAmount.add(personalStake.actualAmount);
          personalStake.actualAmount = 0;
      }
      sc.personalStakeIndex = i;

      uint256 unstakedForSender = unstakeAmount.sub(unstakedForOthers);
      sc.totalStakedFor = sc.totalStakedFor.sub(unstakedForSender);
      totalStakedAmount = totalStakedAmount.sub(unstakeAmount);
      require(stakingToken.transfer(_transferTo, unstakeAmount), "Unable to withdraw");
      emit Unstaked(_unstakeFor, unstakedForSender, sc.totalStakedFor, _data);

      checkAndUpdateCapForUnstakeFor(unstakeAmount);
      return unstakeAmount;
  }

  uint256[49] private ______gap;
}
