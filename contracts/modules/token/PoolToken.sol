pragma solidity ^0.5.12;

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Mintable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Burnable.sol";
import "../../interfaces/token/IPoolTokenBalanceChangeRecipient.sol";
import "../../common/Module.sol";
import "./DistributionToken.sol";

contract PoolToken is Module, ERC20, ERC20Detailed, ERC20Mintable, ERC20Burnable, DistributionToken {

    bool allowTransfers;

    function initialize(address _pool, string memory poolName, string memory poolSymbol) public initializer {
        Module.initialize(_pool);
        ERC20Detailed.initialize(poolName, poolSymbol, 18);
        ERC20Mintable.initialize(_msgSender());
    }

    function setAllowTransfers(bool _allowTransfers) public onlyOwner {
        allowTransfers = _allowTransfers;
    }

    /**
     * @dev Overrides ERC20Burnable burnFrom to allow unlimited transfers by SavingsModule
     */
    function burnFrom(address from, uint256 value) public {
        address savingsModule = getModuleAddress(MODULE_SAVINGS);
        if (_msgSender() == savingsModule) {
            //Skip decrease allowance
            _burn(from, value);
        }else{
            super.burnFrom(from, value);
        }
    }

    function _transfer(address sender, address recipient, uint256 amount) internal {
        if( !allowTransfers && 
            (sender != address(this)) //transfers from *this* used for distributions
        ){
            revert("PoolToken: transfers between users disabled");
        }
        super._transfer(sender, recipient, amount);
    } 

    function userBalanceChanged(address account) internal {
        IPoolTokenBalanceChangeRecipient savings = IPoolTokenBalanceChangeRecipient(getModuleAddress(MODULE_SAVINGS));
        savings.poolTokenBalanceChanged(account);
    }

}