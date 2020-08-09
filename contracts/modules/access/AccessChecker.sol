pragma solidity ^0.5.12;

import "../../common/Module.sol";
import "../../interfaces/access/IAccessModule.sol";


contract AccessChecker is Module {
    modifier operationAllowed(IAccessModule.Operation operation) {
        IAccessModule am = IAccessModule(getModuleAddress(MODULE_ACCESS));
        require(am.isOperationAllowed(operation, _msgSender()), "AccessChecker: operation not allowed");
        _;
    }
}