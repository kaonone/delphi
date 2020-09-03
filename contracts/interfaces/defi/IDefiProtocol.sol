pragma solidity ^0.5.12;

interface IDefiProtocol {
    /**
     * @notice Transfer tokens from sender to DeFi protocol
     * @param token Address of token
     * @param amount Value of token to deposit
     * @return new balances of each token
     */
    function handleDeposit(address token, uint256 amount) external;

    function handleDeposit(address[] calldata tokens, uint256[] calldata amounts) external;

    /**
     * @notice Transfer tokens from DeFi protocol to beneficiary
     * @param token Address of token
     * @param amount Denormalized value of token to withdraw
     * @return new balances of each token
     */
    function withdraw(address beneficiary, address token, uint256 amount) external;

    /**
     * @notice Transfer tokens from DeFi protocol to beneficiary
     * @param amounts Array of amounts to withdraw, in order of supportedTokens()
     * @return new balances of each token
     */
    function withdraw(address beneficiary, uint256[] calldata amounts) external;

    /**
     * @notice Claim rewards. Reward tokens will be stored on protocol balance.
     * @return tokens and their amounts received
     */
    function claimRewards() external returns(address[] memory tokens, uint256[] memory amounts);

    /**
     * @notice Withdraw reward tokens to user
     * @dev called by SavingsModule
     * @param token Reward token to withdraw
     * @param user Who should receive tokens
     * @param amount How many tokens to send
     */
    function withdrawReward(address token, address user, uint256 amount) external;

    /**
     * @dev This function is not view because on some protocols 
     * (Compound, RAY with Compound oportunity) it may cause storage writes
     */
    function balanceOf(address token) external returns(uint256);

    /**
     * @notice Balance of all tokens supported by protocol 
     * @dev This function is not view because on some protocols 
     * (Compound, RAY with Compound oportunity) it may cause storage writes
     */
    function balanceOfAll() external returns(uint256[] memory); 

    /**
     * @notice Returns optimal proportions of underlying tokens 
     * to prevent fees on deposit/withdrawl if supplying multiple tokens
     * @dev This function is not view because on some protocols 
     * (Compound, RAY with Compound oportunity) it may cause storage writes
     * same as balanceOfAll()
     */
    function optimalProportions() external returns(uint256[] memory);

    /**
    * @notice Returns normalized (to USD with 18 decimals) summary balance 
    * of pool using all tokens in this protocol
    */
    function normalizedBalance() external returns(uint256);

    function supportedTokens() external view returns(address[] memory);

    function supportedTokensCount() external view returns(uint256);

    function supportedRewardTokens() external view returns(address[] memory);

    function isSupportedRewardToken(address token) external view returns(bool);

    /**
     * @notice Returns if this protocol can swap all it's normalizedBalance() to specified token
     */
    function canSwapToToken(address token) external view returns(bool);

}