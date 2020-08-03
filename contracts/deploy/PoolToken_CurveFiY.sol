pragma solidity ^0.5.12;

import "../modules/token/PoolToken.sol";

contract PoolToken_CurveFiY is PoolToken {
    function initialize(address _pool) public initializer {
        PoolToken.initialize(
            _pool, 
            "Akropolis Delpi Savings - CurveFi - yDAI/yUSDC/yUSDT",
            "ADST-CF-Y"
        );
    }    
}
