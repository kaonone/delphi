pragma solidity ^0.5.12;

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/SafeERC20.sol";
import "../interfaces/defi/IComptroller.sol";
import "../common/Base.sol";

/**
 * @notice Simple token which everyone can mint
 */
contract ComptrollerStub is Base, IComptroller {
    uint256 public constant ANNUAL_SECONDS = 365*24*60*60+(24*60*60/4);  // Seconds in a year + 1/4 day to compensate leap years
    uint256 constant EXP = 1e18;

    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct AddressInfo{
        mapping(address=>uint256) cBalances;
        uint256 lastUpdate;
    }

    IERC20 comp;
    mapping(address=>AddressInfo) cHolders;
    address[] cTokens;
    uint256 public targetAPY;
    uint256 public baseCTokenToCompRatio;

    function initialize(address _comp) public initializer {
        Base.initialize();
        comp = IERC20(_comp);
        targetAPY = EXP/10; //10%
        baseCTokenToCompRatio = 1000000 * EXP;
    }

    function claimComp(address holder) public {
        AddressInfo storage ai = cHolders[holder];
        if(ai.lastUpdate != 0 && ai.lastUpdate < now) {
            sendComp(holder, ai);
        }else {
            updateTokenBalances(holder, ai);
        }
        ai.lastUpdate = now;
    }

    function updateTokenBalances(address holder, AddressInfo storage ai) private {
        for(uint256 i=0; i < cTokens.length; i++) {
            address token = cTokens[i];
            ai.cBalances[token] = IERC20(token).balanceOf(holder);
        }
    }
    function sendComp(address holder, AddressInfo storage ai) private {
        uint256 period = now.sub(ai.lastUpdate);
        uint256 compAmount;
        for(uint256 i=0; i < cTokens.length; i++) {
            address token = cTokens[i];
            uint256 prevBalance = ai.cBalances[token];
            // uint256 compAmount += prevBalance
            //     .mul(period).div(ANNUAL_SECONDS)
            //     .mul(targetAPY).div(EXP)
            //     .mul(EXP).div(baseCTokenToCompRatio);
            compAmount = compAmount.add(prevBalance.mul(period).mul(targetAPY).div(ANNUAL_SECONDS).div(baseCTokenToCompRatio));
        }
        comp.safeTransfer(holder, compAmount);
    }


    function setSupportedCTokens(address[] memory _cTokens) public {
        cTokens = _cTokens;
    }

    function setTargetAPY(uint256 _targetAPY) public {
        targetAPY = _targetAPY;
    }

    function setBaseCTokenToCompRatio(uint256 _baseCTokenToCompRatio) public {
        baseCTokenToCompRatio = _baseCTokenToCompRatio;
    }

    function getCompAddress() public view returns (address) {
        return address(comp);
    }

    function supportedCTokens() public view returns (address[] memory) {
        return cTokens;
    }
}

