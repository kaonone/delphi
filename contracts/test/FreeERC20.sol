pragma solidity ^0.5.0;

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Burnable.sol";
import "../common/Base.sol";

contract FreeERC20 is Base, ERC20Detailed, ERC20Burnable {

    function initialize(string memory name, string memory symbol) public initializer {
        Base.initialize();
        ERC20Detailed.initialize(name, symbol, 18);
    }

    function initialize(string memory name, string memory symbol, uint8 decimals) public initializer {
        Base.initialize();
        ERC20Detailed.initialize(name, symbol, decimals);
    }

    /**
    * @notice Allows mintinf of this token
    * @param amount Amount to  mint
    */
    function mint(uint256 amount) public returns (bool) {
        _mint(_msgSender(), amount);
        return true;
    }

    /**
    * @notice Allows minting of this token
    * @param account Receiver ot minted tokens
    * @param amount Amount to  mint
    */
    function mint(address account, uint256 amount) public returns (bool) {
        _mint(account, amount);
        return true;
    }

    /**
    * @notice Allows minting of this token
    * @param account Receiver ot minted tokens
    * @param amount Amount to  mint
    */
    function allocateTo(address account, uint256 amount) public {
        _mint(account, amount);
    } 
}
