pragma solidity ^0.5.12;

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";

import "../interfaces/defi/IUniswap.sol";

contract UniswapStub is IUniswap {

    function swapExactTokensForTokens(uint256 amountIn, uint256 amountOutMin, address[] memory path, address to, uint256 deadline) public {
        require(deadline >= block.timestamp, 'UniswapV2Router: EXPIRED');
        IERC20(path[0]).transferFrom(msg.sender, address(this), amountIn);

        uint256 l = path.length - 1;
        IERC20(path[l]).transfer(to, amountIn);
    }
}