pragma solidity ^0.5.16;

contract IComptroller {
    function claimComp(address holder) public;
    function getCompAddress() public view returns (address);
}