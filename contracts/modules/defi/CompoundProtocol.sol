pragma solidity ^0.5.12;

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "../../interfaces/defi/IDefiProtocol.sol";
import "../../interfaces/defi/ICErc20.sol";
import "../../interfaces/defi/IComptroller.sol";
import "../../common/Module.sol";
import "./DefiOperatorRole.sol";
import "./ProtocolBase.sol";

/**
 * RAY Protocol support module which works with only one base token
 */
contract CompoundProtocol is ProtocolBase {
    uint256 constant MAX_UINT256 = uint256(-1);

    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IERC20 public baseToken;
    uint8 public decimals;
    ICErc20 public cToken;
    IComptroller public comptroller;
    IERC20 public compToken;

    function initialize(address _pool, address _token, address _cToken, address _comptroller) public initializer {
        ProtocolBase.initialize(_pool);
        baseToken = IERC20(_token);
        cToken = ICErc20(_cToken);
        decimals = ERC20Detailed(_token).decimals();
        baseToken.safeApprove(_cToken, MAX_UINT256);
        comptroller = IComptroller(_comptroller);
        compToken = IERC20(comptroller.getCompAddress());
    }

    function handleDeposit(address token, uint256 amount) public onlyDefiOperator {
        require(token == address(baseToken), "CompoundProtocol: token not supported");
        cToken.mint(amount);
    }

    function handleDeposit(address[] memory tokens, uint256[] memory amounts) public onlyDefiOperator {
        require(tokens.length == 1 && amounts.length == 1, "CompoundProtocol: wrong count of tokens or amounts");
        handleDeposit(tokens[0], amounts[0]);
    }

    function withdraw(address beneficiary, address token, uint256 amount) public onlyDefiOperator {
        require(token == address(baseToken), "CompoundProtocol: token not supported");

        cToken.redeemUnderlying(amount);
        baseToken.safeTransfer(beneficiary, amount);
    }

    function withdraw(address beneficiary, uint256[] memory amounts) public onlyDefiOperator {
        require(amounts.length == 1, "CompoundProtocol: wrong amounts array length");

        cToken.redeemUnderlying(amounts[0]);
        baseToken.safeTransfer(beneficiary, amounts[0]);
    }

    function balanceOf(address token) public returns(uint256) {
        if (token != address(baseToken)) return 0;
        return cToken.balanceOfUnderlying(address(this));
    }
    
    function balanceOfAll() public returns(uint256[] memory) {
        uint256[] memory balances = new uint256[](1);
        balances[0] = balanceOf(address(baseToken));
        return balances;
    }

    function normalizedBalance() public returns(uint256) {
        return normalizeAmount(address(baseToken), balanceOf(address(baseToken)));
    }

    function optimalProportions() public returns(uint256[] memory) {
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1e18;
        return amounts;
    }

    function canSwapToToken(address token) public view returns(bool) {
        return (token == address(baseToken));
    }    

    function supportedTokens() public view returns(address[] memory){
        address[] memory tokens = new address[](1);
        tokens[0] = address(baseToken);
        return tokens;
    }

    function supportedTokensCount() public view returns(uint256) {
        return 1;
    }

    function supportedRewardTokens() public view returns(address[] memory) {
        uint256 defaultRTCount = defaultRewardTokensCount();
        address[] memory rtokens = new address[](defaultRTCount+1);
        rtokens = defaultRewardTokensFillArray(rtokens);
        rtokens[defaultRTCount] = address(compToken);
        return rtokens;
    }

    function cliamRewardsFromProtocol() internal {
        address[] memory holders = new address[](1);
        holders[0] = address(this);
        address[] memory cTokens = new address[](1);
        cTokens[0] = address(cToken);
        comptroller.claimComp(holders, cTokens, false, true);
    }

    function normalizeAmount(address, uint256 amount) internal view returns(uint256) {
        if (decimals == 18) {
            return amount;
        } else if (decimals > 18) {
            return amount.div(10**(uint256(decimals)-18));
        } else if (decimals < 18) {
            return amount.mul(10**(18-uint256(decimals)));
        }
    }

    function denormalizeAmount(address, uint256 amount) internal view returns(uint256) {
        if (decimals == 18) {
            return amount;
        } else if (decimals > 18) {
            return amount.mul(10**(uint256(decimals)-18));
        } else if (decimals < 18) {
            return amount.div(10**(18-uint256(decimals)));
        }
    }

}
