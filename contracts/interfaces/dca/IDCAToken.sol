pragma solidity ^0.5.12;

interface IDCAToken {

    //Adress for Token as Currency for Buy. Default: WBTC
    address internal constant WBTC_TOKEN_ADDRESS = 0xC4375B7De8af5a38a93548eb8453a498222C4fF2;


    //Adress for Token as Currency of Deposit. Default: USDC
    address internal constant STACKING_TOKEN_ADDRESS = 0xCFd6e4044DD6E6CE64AeD0711F849C7B9134d7Db;


    event Supply( 
        uint256 value, 
        uint256 tokenAddress,
        uint256 indexed tokenId,
    );

    event Redeem(
        uint256 value, 
        uint256 tokenAddress,
        uint256 indexed tokenId,
    );



    function balanceOf(address token) external view returns
    (
        uint256 balance
    );

    function dcaTokenFor(address account) external view returns
    (
        uint256 tokenId;
    );

    function supply(
        uint256 value    
    )  external returns (bool);


     function  withdraw(
        address token,
        uint256 value    
    )  external returns (bool);

}