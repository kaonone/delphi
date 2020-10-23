pragma solidity ^0.5.12;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/roles/CapperRole.sol";
import "../../interfaces/defi/IDefiProtocol.sol";
import "../../common/Module.sol";
import "../access/AccessChecker.sol";
import "../token/PoolToken.sol";
import "./RewardDistributions.sol";

contract SavingsCap is CapperRole {

    event UserCapEnabledChange(bool enabled);
    event UserCapChanged(address indexed protocol, address indexed user, uint256 newCap);
    event DefaultUserCapChanged(address indexed protocol, uint256 newCap);
    event ProtocolCapEnabledChange(bool enabled);
    event ProtocolCapChanged(address indexed protocol, uint256 newCap);
    event VipUserEnabledChange(bool enabled);
    event VipUserChanged(address indexed protocol, address indexed user, bool isVip);

    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    struct ProtocolCapInfo {
        mapping(address => uint256) userCap; //Limit of pool tokens which can be minted for a user during deposit
        mapping(address=>bool) isVipUser;       
    }

    mapping(address => ProtocolCapInfo) protocolsCapInfo; //Mapping of protocol to data we need to calculate APY and do distributions

    bool public userCapEnabled;
    bool public protocolCapEnabled;
    mapping(address=>uint256) public defaultUserCap;
    mapping(address=>uint256) public protocolCap;
    bool public vipUserEnabled;                         // Enable VIP user (overrides protocol cap)


    function initialize(address _capper) public initializer {
        CapperRole.initialize(_capper);
    }

    function setUserCapEnabled(bool _userCapEnabled) public onlyCapper {
        userCapEnabled = _userCapEnabled;
        emit UserCapEnabledChange(userCapEnabled);
    }

    // function setUserCap(address _protocol, address user, uint256 cap) public onlyCapper {
    //     protocols[_protocol].userCap[user] = cap;
    //     emit UserCapChanged(_protocol, user, cap);
    // }

    // function setUserCap(address _protocol, address[] calldata users, uint256[] calldata caps) external onlyCapper {
    //     require(users.length == caps.length, "SavingsModule: arrays length not match");
    //     for(uint256 i=0;  i < users.length; i++) {
    //         protocols[_protocol].userCap[users[i]] = caps[i];
    //         emit UserCapChanged(_protocol, users[i], caps[i]);
    //     }
    // }

    function setVipUserEnabled(bool _vipUserEnabled) public onlyCapper {
        vipUserEnabled = _vipUserEnabled;
        emit VipUserEnabledChange(_vipUserEnabled);
    }

    function setVipUser(address _protocol, address user, bool isVip) public onlyCapper {
        protocolsCapInfo[_protocol].isVipUser[user] = isVip;
        emit VipUserChanged(_protocol, user, isVip);
    }
    
    function setDefaultUserCap(address _protocol, uint256 cap) public onlyCapper {
        defaultUserCap[_protocol] = cap;
        emit DefaultUserCapChanged(_protocol, cap);
    }

    function setProtocolCapEnabled(bool _protocolCapEnabled) public onlyCapper {
        protocolCapEnabled = _protocolCapEnabled;
        emit ProtocolCapEnabledChange(protocolCapEnabled);
    }

    function setProtocolCap(address _protocol, uint256 cap) public onlyCapper {
        protocolCap[_protocol] = cap;
        emit ProtocolCapChanged(_protocol, cap);
    }

    function getUserCapLeft(address _protocol, uint256 _balance) view public returns(uint256) {
        uint256 cap;
        if (_balance < defaultUserCap[_protocol]) {
            cap = defaultUserCap[_protocol] - _balance;
        }
        return cap;
    }

    function isVipUser(address _protocol, address user) view public returns(bool){
        return protocolsCapInfo[_protocol].isVipUser[user];
    }

    function isProtocolCapExceeded(uint256 _poolSupply, address _protocol, address _user) view public returns(bool) {
        if (protocolCapEnabled) {
            if ( !(vipUserEnabled && isVipUser(_protocol, _user)) ) {
                if (_poolSupply > protocolCap[_protocol]) {
                    return true;
                }
            }
        }
        return false;
    }

}
