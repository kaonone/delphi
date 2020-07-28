pragma solidity ^0.5.12;

interface IPoolTokenBalanceChangeRecipient {
    function poolTokenBalanceChanged(address user) external; 
}