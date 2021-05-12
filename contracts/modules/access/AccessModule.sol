pragma solidity ^0.5.12;

import "@openzeppelin/contracts-ethereum-package/contracts/lifecycle/Pausable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/roles/WhitelistedRole.sol";
import "../../common/Module.sol";
import "../../interfaces/access/IAccessModule.sol";

contract AccessModule is Module, IAccessModule, Pausable, WhitelistedRole {
    event WhitelistForAllStatusChange(bool enabled);
    event WhitelistForIntermediateSendersStatusChange(bool enabled);

    bool public whitelistEnabledForAll;
    bool public whitelistEnabledForIntermediateSenders;
    mapping(uint8=>uint256) public maxGasLeft; //Zero value means no limit

    function initialize(address _pool) public initializer {
        Module.initialize(_pool);
        Pausable.initialize(_msgSender());
        WhitelistedRole.initialize(_msgSender());
    }

    function setWhitelistForAll(bool enabled) public onlyWhitelistAdmin {
        whitelistEnabledForAll = enabled;
        emit WhitelistForAllStatusChange(enabled);
    }
    
    function setWhitelistForIntermediateSenders(bool enabled) public onlyWhitelistAdmin {
        whitelistEnabledForIntermediateSenders = enabled;
        emit WhitelistForIntermediateSendersStatusChange(enabled);
    }

    function setMaxGasLeft(Operation operation, uint256 value) public onlyWhitelistAdmin {
        maxGasLeft[uint8(operation)] = value;
    }

    function getMaxGasLeft(Operation operation) public view returns(uint256) {
        return maxGasLeft[uint8(operation)];
    }

    function isOperationAllowed(Operation operation, address sender) public view returns(bool) {
        (operation);    //noop to prevent compiler warning
        if (paused()) return false;
        if (whitelistEnabledForAll) {
            return isWhitelisted(sender);
        } else if(
            whitelistEnabledForIntermediateSenders && 
            tx.origin != sender
        ){
            return isWhitelisted(sender);
        } else {
            return true;
        }
    }
}
