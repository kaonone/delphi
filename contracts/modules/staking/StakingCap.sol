pragma solidity ^0.5.12;

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";

import "@openzeppelin/contracts-ethereum-package/contracts/access/roles/CapperRole.sol";

contract StakingCap is CapperRole  {
  using SafeMath for uint256;

  bool public userCapEnabled;

  mapping(address => uint256) public userCap; //Limit of pool tokens which can be minted for a user during deposit
  
  uint256 public defaultUserCap;
  bool public stakingCapEnabled;
  uint256 public stakingCap;


  bool public vipUserEnabled;
  mapping(address => bool) public isVipUser;
  
  event VipUserEnabledChange(bool enabled);
  event VipUserChanged(address indexed user, bool isVip);

  event StakingCapChanged(uint256 newCap);
  event StakingCapEnabledChange(bool enabled);

  //global cap
  event DefaultUserCapChanged(uint256 newCap);

  event UserCapEnabledChange(bool enabled);

  event UserCapChanged(address indexed user, uint256 newCap);


  modifier isUserCapEnabledForStakeFor(uint256 stake, uint256 totalStaked, uint256 totalStakedFor) {

    if (stakingCapEnabled && !(vipUserEnabled && isVipUser[_msgSender()])) {
        require((stakingCap > totalStaked && (stakingCap-totalStaked >= stake)), "StakingModule: stake exeeds staking cap");
    }

    if(userCapEnabled) {
          uint256 cap = userCap[_msgSender()];
          //check default user cap settings
          if (defaultUserCap > 0) {
              //get new cap
              if (defaultUserCap >= totalStakedFor) {
                cap = defaultUserCap.sub(totalStakedFor);
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

  function initialize(address _capper) public initializer {
        CapperRole.initialize(_capper);
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

  function isUserCapEnabled() public view returns(bool) {
    return userCapEnabled;
  }


  function iStakingCapEnabled() public view returns(bool) {
    return stakingCapEnabled;
  }
}