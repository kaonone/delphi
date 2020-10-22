pragma solidity ^0.5.16;

interface ICurveFiMinter {
    function mint(address gauge_addr) external;
    function mint_for(address gauge_addr, address _for) external;
    function minted(address _for, address gauge_addr) external returns(uint256);
}