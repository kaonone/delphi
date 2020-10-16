pragma solidity ^0.5.12;

import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/GSN/Context.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/Roles.sol";

contract RewardManagerRole is Initializable, Context {
    using Roles for Roles.Role;

    event RewardManagerAdded(address indexed account);
    event RewardManagerRemoved(address indexed account);

    Roles.Role private _managers;

    function initialize(address sender) public initializer {
        if (!isRewardManager(sender)) {
            _addRewardManager(sender);
        }
    }

    modifier onlyRewardManager() {
        require(isRewardManager(_msgSender()), "RewardManagerRole: caller does not have the RewardManager role");
        _;
    }

    function addRewardManager(address account) public onlyRewardManager {
        _addRewardManager(account);
    }

    function renounceRewardManager() public {
        _removeRewardManager(_msgSender());
    }

    function isRewardManager(address account) public view returns (bool) {
        return _managers.has(account);
    }

    function _addRewardManager(address account) internal {
        _managers.add(account);
        emit RewardManagerAdded(account);
    }

    function _removeRewardManager(address account) internal {
        _managers.remove(account);
        emit RewardManagerRemoved(account);
    }

}

