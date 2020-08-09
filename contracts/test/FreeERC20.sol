// SPDX-License-Identifier: MIT

pragma solidity ^0.5.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";

contract FreeERC20 is ERC20, ERC20Detailed {
    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals,
        uint256 amountToMint
    ) public ERC20Detailed(name, symbol, decimals) {
        _mint(msg.sender, amountToMint);
    }
}
