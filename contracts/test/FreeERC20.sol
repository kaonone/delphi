pragma solidity ^0.5.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";

contract FreeERC20 is ERC20, ERC20Detailed {
    constructor(string memory name, string memory symbol)
        public
        ERC20Detailed(name, symbol, 18)
    {
        _mint(msg.sender, 100000e18);
    }
}
