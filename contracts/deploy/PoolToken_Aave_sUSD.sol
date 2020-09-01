pragma solidity ^0.5.12;

import "../modules/token/PoolToken.sol";

contract PoolToken_Aave_sUSD is PoolToken {
    function initialize(address _pool) public initializer {
        PoolToken.initialize(
            _pool, 
            "Delphi Aave sUSD",
            "daSUSD"
        );
    }    
}
