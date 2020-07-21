pragma solidity ^0.5.12;

interface IDCAStrategy {

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
    );

    function dcaStrategyFor(address account) external view returns
    (
        uint256 tokenId
    );

    function createDCAStrategy(uint256 tokenId,
        uint256 duration,
        uint256 minAmount) external returns
    (
        bool
    );
   

    function removeDCAStrategy(uint256 tokenId) external returns
    (
        bool
    );
 
    function exchange() external returns (
        bool
    );
}
