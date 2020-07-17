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

    function dcaStrategyFor(address account) external view returns
    (
        uint256 tokenId;
    );

    function createDCAStrategy(uint256 indexed tokenId,
        uint256 duration,
        uint256 minAmount) external view returns
    (
        bool
    );


    function createDCAStrategy(uint256 indexed tokenId,
        uint256 duration,
        uint256 minAmount) external view returns
    (
        bool
    );


    function removeDCAStrategy(uint256 indexed tokenId) external view returns
    (
        bool
    );
}
