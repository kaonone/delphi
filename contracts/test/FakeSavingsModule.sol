pragma solidity ^0.5.0;

import "contracts/utils/TransferHelper.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";

contract FakeSavingsModule {
    using SafeMath for uint256;
    using TransferHelper for address;

    struct Token {
        address originalAdress;
        address poolAddress;
    }

    mapping(address => Token) public tokens;

    constructor(
        address _usdc,
        address _wbtc,
        address _weth,
        address _usdcPool,
        address _wbtcPool,
        address _wethPool
    ) public {
        tokens[_usdc] = Token({originalAdress: _usdc, poolAddress: _usdcPool});
        tokens[_wbtc] = Token({originalAdress: _wbtc, poolAddress: _wbtcPool});
        tokens[_weth] = Token({originalAdress: _weth, poolAddress: _wethPool});
    }

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
    ) public returns (uint256[] memory) {
        (_protocol);

        for (uint256 i = 0; i < _tokens.length; i++) {
            _tokens[i].safeTransferFrom(
                msg.sender,
                address(this),
                _dnAmounts[i]
            );

            tokens[_tokens[i]].poolAddress.safeTransfer(
                msg.sender,
                _dnAmounts[i]
            );
        }
        return _dnAmounts;
    }

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
    ) public returns (uint256) {
        (_protocol, maxNAmount);

        token.safeTransferFrom(msg.sender, address(this), dnAmount);

        uint256 amountTosend = dnAmount.mul(2);

        tokens[token].originalAdress.safeTransfer(msg.sender, amountTosend);

        return amountTosend;
    }

    /**
     * @notice Withdraw reward tokens for user
     * @param rewardTokens Array of tokens to withdraw
     */
    function withdrawReward(address[] memory rewardTokens)
        public
        returns (uint256[] memory)
    {
        uint256 rewardAmount = 100e18;

        uint256[] memory rAmounts = new uint256[](rewardTokens.length);

        for (uint256 i = 0; i < rewardTokens.length; i++) {
            rewardTokens[i].safeTransfer(msg.sender, rewardAmount);

            rAmounts[i] = rewardAmount;
        }

        return rAmounts;
    }
}
