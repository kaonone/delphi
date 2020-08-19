pragma solidity ^0.5.16;

interface ICurveFiMinter {
    function mint(address gauge_addr) external;
}