pragma solidity ^0.5.16;

interface ICurveFiLiquidityGauge {
    //Addresses of tokens
    function lp_token() external returns(address);
    function crv_token() external returns(address);
 
    //Work with LP tokens
    function balanceOf(address addr) external view returns (uint256);
    function deposit(uint256 _value) external;
    function withdraw(uint256 _value) external;

    //Work with CRV
    function claimable_tokens(address addr) external returns (uint256);
    function minter() external view returns(address); //use minter().mint(gauge_addr) to claim CRV

    function integrate_fraction(address _for) external returns(uint256);
    function user_checkpoint(address _for) external returns(bool);
}