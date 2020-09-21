pragma solidity ^0.5.12;

import "./IDefiProtocol.sol";

contract IDefiStrategy is IDefiProtocol { 

    function performStrategy() external;
    function withdrawStrategyYield(address beneficiary, uint256 _amount) external;
}