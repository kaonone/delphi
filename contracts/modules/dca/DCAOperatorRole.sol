pragma solidity ^0.5.12;

import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/GSN/Context.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/Roles.sol";

contract DCAOperatorRole is Initializable, Context {
    using Roles for Roles.Role;

    event DCAOperatorAdded(address indexed account);
    event DCAOperatorRemoved(address indexed account);

    Roles.Role private _operators;

    function initialize(address sender) public initializer {
        if (!isDCAOperator(sender)) {
            _addDCAOperator(sender);
        }
    }

    modifier onlyDCAOperator() {
        require(
            isDCAOperator(_msgSender()),
            "DCAOperatorRole: caller does not have the DCAOperator role"
        );
        _;
    }

    function addDCAOperator(address account) public onlyDCAOperator {
        _addDCAOperator(account);
    }

    function renounceDCAOperator() public {
        _removeDCAOperator(_msgSender());
    }

    function isDCAOperator(address account) public view returns (bool) {
        return _operators.has(account);
    }

    function _addDCAOperator(address account) internal {
        _operators.add(account);
        emit DCAOperatorAdded(account);
    }

    function _removeDCAOperator(address account) internal {
        _operators.remove(account);
        emit DCAOperatorRemoved(account);
    }
}
