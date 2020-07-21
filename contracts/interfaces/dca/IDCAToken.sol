pragma solidity ^0.5.12;

interface IDCAToken {


    event Supply( 
        uint256 value, 
        uint256 tokenAddress,
        uint256 indexed tokenId
    );

    event Redeem(
        uint256 value, 
        uint256 tokenAddress,
        uint256 indexed tokenId
    );



    function totalSupplyFor(address token) external view returns
    (
        uint256 totalSupply
    );

    function balanceOf(address token) external view returns
    (
        uint256 balance
    );

    function dcaTokenFor(address account) external view returns
    (
        uint256 tokenId
    );

    function supply(
        uint256 value    
    )  external returns (bool);


     function  withdraw(
        address token,
        uint256 amount   
    )  external returns (bool);

}