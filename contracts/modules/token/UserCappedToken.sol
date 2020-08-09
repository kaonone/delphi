pragma solidity ^0.5.12;

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/roles/CapperRole.sol";

contract UserCappedToken is ERC20, CapperRole {
    
    bool public userCapEnabled;
    mapping(address=>uint256) public userCap;

    function setUserCapEnabled(bool enabled) public onlyCapper {
        userCapEnabled = enabled;
    }

    function setUserCap(address account, uint256 amount) public onlyCapper {
        userCap[account] = amount;
    }

    function _transfer(address sender, address recipient, uint256 amount) internal {
        super._transfer(sender, recipient, amount);
        requireBalanceUnderCap(recipient);
    }
    function _mint(address account, uint256 amount) internal {
        super._mint(account, amount);
        requireBalanceUnderCap(account);
    }

    function requireBalanceUnderCap(address account) private view returns(bool) {
        if(userCapEnabled) {
            require(balanceOf(account) <= userCap[account], "UserCappedToken: balance exeeds cap" );
        }
    }
}