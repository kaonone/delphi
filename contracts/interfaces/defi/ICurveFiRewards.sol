pragma solidity ^0.5.16;

interface ICurveFiRewards {
    function stake(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function getReward() external;
    function earned(address account) external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
}