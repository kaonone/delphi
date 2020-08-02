pragma solidity ^0.5.0;

contract ISavingsModule {
    /**
     * @notice Deposit tokens to a protocol
     * @param _protocol Protocol to deposit tokens
     * @param _tokens Array of tokens to deposit
     * @param _dnAmounts Array of amounts (denormalized to token decimals)
     */
    function deposit(
        address _protocol,
        address[] memory _tokens,
        uint256[] memory _dnAmounts
    ) public returns (uint256);

    /**
     * Withdraw token from protocol
     * @param _protocol Protocol to withdraw from
     * @param token Token to withdraw
     * @param dnAmount Amount to withdraw (denormalized)
     * @param maxNAmount Max amount of PoolToken to burn
     * @return Amount of PoolToken burned from user
     */
    function withdraw(
        address _protocol,
        address token,
        uint256 dnAmount,
        uint256 maxNAmount
    ) public returns (uint256);

    /**
     * @notice Withdraw reward tokens for user
     * @param rewardTokens Array of tokens to withdraw
     */
    function withdrawReward(address[] memory rewardTokens)
        public
        returns (uint256[] memory);
}
