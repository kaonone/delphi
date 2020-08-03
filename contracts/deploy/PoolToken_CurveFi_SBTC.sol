pragma solidity ^0.5.12;

import "../modules/token/PoolToken.sol";

contract PoolToken_CurveFi_Y is PoolToken {
    function initialize(address _pool) public initializer {
        PoolToken.initialize(
            _pool, 
            "Akropolis Delpi Savings - CurveFi - renBTC/wBTC/sBTC",
            "ADST-CF-SBTC"
        );
    }    
}
