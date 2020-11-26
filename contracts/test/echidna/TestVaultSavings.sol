pragma solidity ^0.5.12;

import "../../modules/savings/VaultSavingsModule.sol";

contract TestVaultSavings is VaultSavingsModule {
    constructor() public {}
    function echidna_vault_registered() public view returns(bool){
        return registeredVaults.length > 0;
    }

}

