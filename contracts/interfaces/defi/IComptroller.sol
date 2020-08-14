pragma solidity ^0.5.16;

interface IComptroller {
    function claimComp(address holder) external;
    function claimComp(address[] calldata holders, address[] calldata cTokens, bool borrowers, bool suppliers) external;
    function getCompAddress() external view returns (address);
}