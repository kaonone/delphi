pragma solidity ^0.5.12;

interface IDCAStrategy {


    //Adress for Token as Currency for Buy. Default: WBTC
    address internal constant WBTC_TOKEN_ADDRESS = 0xC4375B7De8af5a38a93548eb8453a498222C4fF2;


    //Adress for Token as Currency of Deposit. Default: USDC
    address internal constant STACKING_TOKEN_ADDRESS = 0xCFd6e4044DD6E6CE64AeD0711F849C7B9134d7Db;

    event DCAStrategyUpdated(
        uint256 indexed tokenId,
        uint256 duration,
        uint256 minAmount
    );


    event DCAStrategyRemoved(
        uint256 indexed tokenId
    );

    event Exchange(
        address indexed tokenFrom,
        address indexed tokenTo,
        uint256 amount1,
        uint256 amount2
    )

    function dcaStrategyFor(address account) external view returns
    (
        uint256 tokenId;
    );

    function createDCAStrategy(uint256 indexed tokenId,
        uint256 duration,
        uint256 minAmount) external returns
    (
        bool
    );
   

    function removeDCAStrategy(uint256 indexed tokenId) external returns
    (
        bool
    );
 
    function exchange() external returns (
        bool;
    )
}
