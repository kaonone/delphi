pragma solidity ^0.5.12;

interface ICurveFiSwap { 
    function balances(int128 i) external view returns(uint256);
    function A() external view returns(uint256);
    function fee() external view returns(uint256);
    function coins(int128 i) external view returns (address);
}