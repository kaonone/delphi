pragma solidity ^0.5.12;

import "./IDefiProtocol.sol";

contract IDefiStrategy is IDefiProtocol { 

    function swapToken() external;
}