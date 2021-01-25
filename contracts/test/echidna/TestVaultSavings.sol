pragma solidity ^0.5.12;

import "../../modules/savings/VaultSavingsModule.sol";

contract TestVaultSavings is VaultSavingsModule {
    address public _pool = 0xb18E32002e1c13B0aDD0e0b860245BF429AABe09;
    address public _deployer = 0x260dfB806B62baeBe10083142499f863528dD190;

    constructor() public {
        VaultSavingsModule.initialize(_pool);
    }
    function echidna_vault_registered() public view returns(bool){
        return owner() == _deployer;
    }

}

