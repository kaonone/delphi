pragma solidity ^0.5.12;

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "../../interfaces/access/IAccessModule.sol";
import "../../interfaces/funds/IFundsModule.sol";
import "../../interfaces/liquidity/ILiquidityModule.sol";
import "../../common/Module.sol";

contract LiquidityModule is Module, ILiquidityModule {
    struct LiquidityLimits {
        uint256 lDepositMin;     // Minimal amount of liquid tokens for deposit
        uint256 lWithdrawMin;    // Minimal amount of pTokens for withdraw
    }

    LiquidityLimits public limits;

    modifier operationAllowed(IAccessModule.Operation operation) {
        IAccessModule am = IAccessModule(getModuleAddress(MODULE_ACCESS));
        require(am.isOperationAllowed(operation, _msgSender()), "LiquidityModule: operation not allowed");
        _;
    }

    function initialize(address _pool) public initializer {
        Module.initialize(_pool);
        setLimits(10*10**18, 0);    //10 DAI minimal enter
    }

    /**
     * @notice Deposit amount of lToken
     * @param dnlAmount Amount of liquid tokens to invest
     * @param pAmountMin Minimal amout of pTokens suitable for sender
     */ 
    function deposit(address token, uint256 dnlAmount) public operationAllowed(IAccessModule.Operation.Deposit) {
        require(dnlAmount > 0, "LiquidityModule: lAmount should not be 0");
        uint256 lAmount = fundsModule().normalizeLTokenValue(token, dnlAmount);
        require(lAmount >= limits.lDepositMin, "LiquidityModule: amount should be >= lDepositMin");
        fundsModule().depositLTokens(token, _msgSender(), lAmount);
        fundsModule().mintPTokens(_msgSender(), pAmount);
        emit Deposit(_msgSender(), lAmount);
    }

    /**
     * @notice Withdraw amount of lToken
     */
    function withdraw(uint256 lAmount, address token) public operationAllowed(IAccessModule.Operation.Withdraw) {
        uint256 dnlAmount = fundsModule().denormalizeLTokenValue(token, lAmount);

        uint256 availableLiquidity = fundsModule().lBalance(token);
        require(dnlAmount <= availableLiquidity, "LiquidityModule: not enough liquidity");
        fundsModule().withdrawLTokens(token, _msgSender(), dnlAmount);
        emit Withdraw(_msgSender(), dnlAmount);
    }

    function setLimits(uint256 lDepositMin, uint256 lWithdrawMin) public onlyOwner {
        limits.lDepositMin = lDepositMin;
        limits.pWithdrawMin = lWithdrawMin;
    }

    function fundsModule() internal view returns(IFundsModule) {
        return IFundsModule(getModuleAddress(MODULE_FUNDS));
    }
}