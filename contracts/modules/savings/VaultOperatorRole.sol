pragma solidity ^0.5.12;

import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/GSN/Context.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/Roles.sol";

contract VaultOperatorRole is Initializable, Context {
    using Roles for Roles.Role;

    event VaultOperatorAdded(address indexed account);
    event VaultOperatorRemoved(address indexed account);

    Roles.Role private _managers;

    function initialize(address sender) public initializer {
        if (!isVaultOperator(sender)) {
            _addVaultOperator(sender);
        }
    }

    modifier onlyVaultOperator() {
        require(isVaultOperator(_msgSender()), "VaultOperatorRole: caller does not have the VaultOperator role");
        _;
    }

    function addVaultOperator(address account) public onlyVaultOperator {
        _addVaultOperator(account);
    }

    function renounceVaultOperator() public {
        _removeVaultOperator(_msgSender());
    }

    function isVaultOperator(address account) public view returns (bool) {
        return _managers.has(account);
    }

    function _addVaultOperator(address account) internal {
        _managers.add(account);
        emit VaultOperatorAdded(account);
    }

    function _removeVaultOperator(address account) internal {
        _managers.remove(account);
        emit VaultOperatorRemoved(account);
    }

}

