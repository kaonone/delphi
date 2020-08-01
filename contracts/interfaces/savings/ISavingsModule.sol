pragma solidity ^0.5.0;

interface FakeSavingsModule {
    /**
     * @notice Deposit tokens to a protocol
     * @param _protocol Protocol to deposit tokens
     * @param _tokens Array of tokens to deposit
     * @param _dnAmounts Array of amounts (denormalized to token decimals)
     */
    function deposit(
        address _protocol,
        address[] calldata _tokens,
        uint256[] calldata _dnAmounts
    ) external returns (uint256);

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
    ) external returns (uint256);

    /**
     * @notice Withdraw reward tokens for user.
     * @param rewardToken Token to withdraw.
     */
    function withdrawReward(address rewardToken) external returns (uint256);
}
