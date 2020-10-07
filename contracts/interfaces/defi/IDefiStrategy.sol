pragma solidity ^0.5.12;

contract IDefiStrategy { 
    /**
     * @notice Transfer tokens from sender to DeFi protocol
     * @param token Address of token
     * @param amount Value of token to deposit
     * @return new balances of each token
     */
    function handleDeposit(address token, uint256 amount) external;

    function handleDeposit(address[] calldata tokens, uint256[] calldata amounts) external;

    function withdraw(address beneficiary, address token, uint256 amount) external;

    function withdraw(address beneficiary, uint256[] calldata amounts) external;

    function performStrategy() external;

    function setVault(address _vault) external;

    function normalizedBalance() external returns(uint256);
}