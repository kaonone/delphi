pragma solidity ^0.5.12;

import "../utils/TransferHelper.sol";

contract FakeUniswapRouter {
    using TransferHelper for address;

    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external
        pure
        returns (uint256[] memory amounts)
    {
        (path);

        amounts = new uint256[](2);

        amounts[0] = amountIn;
        amounts[1] = amountIn;

        return amounts;
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts) {
        (deadline);

        path[0].safeTransferFrom(msg.sender, address(this), amountIn);
        path[1].safeTransfer(to, amountOutMin);

        amounts = new uint256[](2);

        amounts[0] = amountIn;
        amounts[1] = amountOutMin;

        return amounts;
    }
}
