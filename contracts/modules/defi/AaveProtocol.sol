pragma solidity ^0.5.12;

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "../../interfaces/defi/IDefiProtocol.sol";
import "../../interfaces/defi/aave/IAaveLendingPoolAddressesProvider.sol";
import "../../interfaces/defi/aave/IAaveLendingPoolCore.sol";
import "../../interfaces/defi/aave/IAaveLendingPool.sol";
import "../../interfaces/defi/aave/IAToken.sol";
import "../../common/Module.sol";
import "./DefiOperatorRole.sol";
import "./ProtocolBase.sol";

contract AaveProtocol is ProtocolBase {
    uint256 constant MAX_UINT256 = uint256(-1);

    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IERC20 public baseToken;
    uint8 public decimals;
    IAToken public aToken;
    IAaveLendingPool public lendingPool;
    IAaveLendingPoolCore public lendingPoolCore;
    uint16 public aaveReferralCode;

    function initialize(address _pool, address _token, address aaveAddressProvider, uint16 _aaveReferralCode) public initializer {
        ProtocolBase.initialize(_pool);
        baseToken = IERC20(_token);
        aaveReferralCode = _aaveReferralCode;
        lendingPool = IAaveLendingPool(IAaveLendingPoolAddressesProvider(aaveAddressProvider).getLendingPool());
        address payable _lendingPool = IAaveLendingPoolAddressesProvider(aaveAddressProvider).getLendingPoolCore();
        lendingPoolCore = IAaveLendingPoolCore(address(_lendingPool));
        aToken = IAToken(lendingPoolCore.getReserveATokenAddress(_token));
        decimals = ERC20Detailed(_token).decimals();

        baseToken.safeApprove(address(lendingPoolCore), MAX_UINT256);
    }

    function handleDeposit(address token, uint256 amount) public onlyDefiOperator {
        require(token == address(baseToken), "AAVEProtocol: token not supported");
        lendingPool.deposit(token, amount, aaveReferralCode);
    }

    function handleDeposit(address[] memory tokens, uint256[] memory amounts) public onlyDefiOperator {
        require(tokens.length == 1 && amounts.length == 1, "AAVEProtocol: wrong count of tokens or amounts");
        handleDeposit(tokens[0], amounts[0]);
    }

    function withdraw(address beneficiary, address token, uint256 amount) public onlyDefiOperator {
        require(token == address(baseToken), "AAVEProtocol: token not supported");

        aToken.redeem(amount);
        baseToken.safeTransfer(beneficiary, amount);
    }

    function withdraw(address beneficiary, uint256[] memory amounts) public onlyDefiOperator {
        require(amounts.length == 1, "AAVEProtocol: wrong amounts array length");

        aToken.redeem(amounts[0]);
        baseToken.safeTransfer(beneficiary, amounts[0]);
    }

    function balanceOf(address token) public returns(uint256) {
        if (token != address(baseToken)) return 0;
        return aToken.balanceOf(address(this));
    }
    
    function balanceOfAll() public returns(uint256[] memory) {
        uint256[] memory balances = new uint256[](1);
        balances[0] = aToken.balanceOf(address(this));
        return balances;
    }

    function normalizedBalance() public returns(uint256) {
        uint256 balance = aToken.balanceOf(address(this));
        return normalizeAmount(balance);
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

    function cliamRewardsFromProtocol() internal {
        //do nothing
    }

    function normalizeAmount(uint256 amount) private view returns(uint256) {
        if (decimals == 18) {
            return amount;
        } else if (decimals > 18) {
            return amount.div(10**(uint256(decimals)-18));
        } else if (decimals < 18) {
            return amount.mul(10**(18-uint256(decimals)));
        }
    }

    function denormalizeAmount(uint256 amount) private view returns(uint256) {
        if (decimals == 18) {
            return amount;
        } else if (decimals > 18) {
            return amount.mul(10**(uint256(decimals)-18));
        } else if (decimals < 18) {
            return amount.div(10**(18-uint256(decimals)));
        }
    }

}
