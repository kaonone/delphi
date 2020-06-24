pragma solidity ^0.5.12;

/**
 * @title Liquidity Module Interface
 * @dev Liquidity module is responsible for deposits, withdrawals and works with Funds module.
 */
interface ILiquidityModule {

    event Deposit(address indexed sender, uint256 lAmount, uint256 pAmount);
    event Withdraw(address indexed sender, uint256 lAmountTotal, uint256 lAmountUser, uint256 pAmount);

    /*
     * @notice Deposit amount of lToken and mint pTokens
     * @param lAmount Amount of liquid tokens to invest
     */ 
    function deposit(address token, uint256 dnlAmount) external;

    /**
     * @notice Withdraw amount of lToken and burn pTokens
     * @param lAmountMin Minimal amount of liquid tokens to withdraw
     */
    function withdraw(uint256 lAmount, address token) external;

}