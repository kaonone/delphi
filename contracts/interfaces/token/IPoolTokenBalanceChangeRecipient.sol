pragma solidity ^0.5.12;

interface IPoolTokenBalanceChangeRecipient {
    function poolTokenBalanceChanged(address user, uint256 newAmount) external; 
}