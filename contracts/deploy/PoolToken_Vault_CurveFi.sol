pragma solidity ^0.5.12;

import "../modules/token/VaultPoolToken.sol";

contract PoolToken_Vault_CurveFi is VaultPoolToken {
    function initialize(address _pool) public initializer {
        PoolToken.initialize(
            _pool, 
            "Delphi Vault CurveFi",
            "dvCRV"
        );
    }    
}
