pragma solidity ^0.5.16;

interface IAaveLendingPoolCore {
    /**
    * @dev gets the aToken contract address for the reserve
    * @param _reserve the reserve address
    * @return the address of the aToken contract
    **/
    function getReserveATokenAddress(address _reserve) external view returns (address);
}