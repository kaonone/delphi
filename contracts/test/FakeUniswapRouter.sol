pragma solidity ^0.5.12;

import "../lib/TransferHelper.sol";

contract FakeUniswapRouter {
    using TransferHelper for address;

    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external returns (uint256[2] memory) {
        tokenIn.safeTransferFrom(msg.sender, address(this), amountIn);
        tokenOut.safeTransfer(msg.sender, amountIn);

        uint256[2] memory amounts;

        amounts[0] = amountIn;
        amounts[1] = amountIn;

        return amounts;
    }
}
