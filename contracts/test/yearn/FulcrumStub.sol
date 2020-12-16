pragma solidity ^0.5.0;

import "../../common/Base.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/SafeERC20.sol";

contract FulcrumStub is Base, ERC20, ERC20Detailed {
    using SafeERC20 for IERC20;

    IERC20 public underlying;

    function initialize(address _underlying) public initializer {
        Base.initialize();
        underlying = IERC20(_underlying);
        string memory name = string(abi.encodePacked("Fulcrum ", ERC20Detailed(_underlying).symbol(), "iToken"));
        string memory symbol = string(abi.encodePacked("i", ERC20Detailed(_underlying).symbol()));
        uint8 decimals = ERC20Detailed(_underlying).decimals();
        ERC20Detailed.initialize(name, symbol, decimals);
    }


    function mint(address receiver, uint256 amount) external payable returns (uint256 mintAmount) {
        underlying.safeTransferFrom(_msgSender(), address(this), amount);
        _mint(receiver, amount);
        return mintAmount;
    }

    function burn(address receiver, uint256 burnAmount) external returns (uint256 loanAmountPaid) {
        _burnFrom(_msgSender(), burnAmount);
        underlying.safeTransfer(receiver, burnAmount);
        return burnAmount;
    }

    function assetBalanceOf(address _owner) external view returns (uint256 balance) {
        return balanceOf(_owner);
    }
}
