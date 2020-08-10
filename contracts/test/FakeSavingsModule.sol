pragma solidity ^0.5.17;

import "../interfaces/savings/ISavingsModule.sol";
import "../utils/TransferHelper.sol";
import "../utils/Normalization.sol";

contract FakeSavingsModule is ISavingsModule {
    using TransferHelper for address;
    using Normalization for uint256;

    mapping(address => address) public tokens;
    mapping(address => uint256) public decimals;

    address[] public supportedRewardTokens_;

    constructor(
        address[] memory _supportedRewardTokens,
        address usdc,
        uint256 usdcDecimals,
        address usdcPoolToken,
        address wbtc,
        uint256 wbtcDecimals,
        address wbtcPoolToken
    ) public {
        for (uint256 i = 0; i < _supportedRewardTokens.length; i++) {
            supportedRewardTokens_.push(_supportedRewardTokens[i]);
        }

        tokens[usdc] = usdcPoolToken;
        decimals[usdc] = usdcDecimals;
        tokens[wbtc] = wbtcPoolToken;
        decimals[wbtc] = wbtcDecimals;
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
    ) public returns (uint256) {
        (_protocol);

        for (uint256 i = 0; i < _tokens.length; i++) {
            _tokens[i].safeTransferFrom(
                msg.sender,
                address(this),
                _dnAmounts[i]
            );

            uint256 nAmount = _dnAmounts[i].normalize(decimals[_tokens[i]]);

            tokens[_tokens[i]].safeTransfer(msg.sender, nAmount);

            return nAmount;
        }
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
        (_protocol);
        (maxNAmount);

        uint256 nAmount = dnAmount.normalize(decimals[token]);
        token.safeTransfer(msg.sender, nAmount);
        return nAmount;
    }

    /**
     * @notice Withdraw reward tokens for user
     * @param rewardTokens Array of tokens to withdraw
     */
    function withdrawReward(address[] memory rewardTokens)
        public
        returns (uint256[] memory)
    {
        uint256[] memory rAmounts = new uint256[](rewardTokens.length);
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            rewardTokens[i].safeTransfer(msg.sender, 100e18);
            rAmounts[i] = 100e18;
        }
        return rAmounts;
    }

    function supportedRewardTokens() public view returns (address[] memory) {
        address[] memory _supportedRewardTokens = new address[](
            supportedRewardTokens_.length
        );

        for (uint256 i = 0; i < supportedRewardTokens_.length; i++) {
            _supportedRewardTokens[i] = supportedRewardTokens_[i];
        }

        return _supportedRewardTokens;
    }
}
