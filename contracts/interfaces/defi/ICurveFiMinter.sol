pragma solidity ^0.5.16;

interface ICurveFiMinter {
    function mint(address gauge_addr) external;
    function minted(address _for, address gauge_addr) external returns(uint256);
}