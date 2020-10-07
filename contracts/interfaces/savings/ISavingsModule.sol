pragma solidity ^0.5.12;

import "../defi/IDefiProtocol.sol";
import "../../modules/token/PoolToken.sol";

//solhint-disable func-order
contract ISavingsModule {

    event ProtocolRegistered(address protocol, address poolToken);
    event YieldDistribution(address indexed poolToken, uint256 amount);
    event DepositToken(address indexed protocol, address indexed token, uint256 dnAmount);
    event Deposit(address indexed protocol, address indexed user, uint256 nAmount, uint256 nFee);
    event WithdrawToken(address indexed protocol, address indexed token, uint256 dnAmount);
    event Withdraw(address indexed protocol, address indexed user, uint256 nAmount, uint256 nFee);

    /**
     * @notice Deposit tokens to several protocols
     * @param _protocols Array of protocols to deposit tokens (each protocol only once)
     * @param _tokens Array of tokens to deposit
     * @param _dnAmounts Array of amounts (denormalized to token decimals)
     */
    function deposit(address[] calldata _protocols, address[] calldata _tokens, uint256[] calldata _dnAmounts) external returns(uint256[] memory);

    /**
     * @notice Deposit tokens to a protocol
     * @param _protocol Protocol to deposit tokens
     * @param _tokens Array of tokens to deposit
     * @param _dnAmounts Array of amounts (denormalized to token decimals)
     */
    function deposit(address _protocol, address[] calldata _tokens, uint256[] calldata _dnAmounts) external returns(uint256);

    /**
     * Withdraw token from protocol
     * @param _protocol Protocol to withdraw from
     * @param token Token to withdraw
     * @param dnAmount Amount to withdraw (denormalized)
     * @param maxNAmount Max amount of PoolToken to burn
     * @return Amount of PoolToken burned from user
     */
    function withdraw(address _protocol, address token, uint256 dnAmount, uint256 maxNAmount) external returns(uint256);
 
    /** 
     * @notice Distributes yield. May be called by bot, if there was no deposits/withdrawals
     */
    function distributeYield() external;

    function poolTokenByProtocol(address _protocol) external view returns(address);
}