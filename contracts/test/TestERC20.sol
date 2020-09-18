pragma solidity ^0.5.12;

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Detailed.sol";

contract TestERC20 is ERC20, ERC20Detailed {
    function initialize(string memory name, string memory symbol, uint8 decimals) public initializer {
        ERC20Detailed.initialize(name, symbol, decimals);
        _mint(_msgSender(), 20000);
    }

}