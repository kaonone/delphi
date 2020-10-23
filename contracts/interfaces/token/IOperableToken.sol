pragma solidity ^0.5.12;

interface IOperableToken {
    function increaseOnHoldValue(address _user, uint256 _amount) external;
    function decreaseOnHoldValue(address _user, uint256 _amount) external;
    function onHoldBalanceOf(address _user) external view returns (uint256);
}