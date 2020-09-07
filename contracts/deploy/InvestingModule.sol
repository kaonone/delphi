pragma solidity ^0.5.12;

import "../modules/savings/SavingsModule.sol";

contract InvestingModule is SavingsModule {

    function initialize(address _pool) public initializer {
        SavingsModule.initialize(_pool);
    }

}
