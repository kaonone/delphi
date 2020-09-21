pragma solidity ^0.5.12;

interface IUniswap {
    function swapExactTokensForTokens(
        uint256,
        uint256,
        address[] calldata,
        address,
        uint256
    ) external;
}