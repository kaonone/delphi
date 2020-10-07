pragma solidity ^0.5.12;

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Mintable.sol";

import "../interfaces/defi/IYErc20.sol";

contract TestYERC20 is IYErc20, ERC20Mintable, ERC20Detailed {
    address public underlying;

    function initialize(string memory name, string memory symbol, uint8 decimals, address _token) public initializer {
        ERC20Detailed.initialize(name, symbol, decimals);
        ERC20Mintable.initialize(msg.sender);
        _mint(_msgSender(), 20000);
        underlying = _token;
    }

    function deposit(uint256 amount) public {
        IERC20(underlying).transferFrom(msg.sender, address(this), amount);
        _mint(_msgSender(), amount);
    }
    
    function withdraw(uint256 shares) public {
        IERC20(underlying).transfer(msg.sender, shares);
        _burnFrom(_msgSender(), shares);
    }
    
    function getPricePerFullShare() public view returns (uint256) {
        return 0;
    }

    function token() external returns(address) {
        return underlying;
    }

}