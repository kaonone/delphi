pragma solidity ^0.5.0;

import "../../common/Base.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/SafeERC20.sol";

import "./Interfaces.sol";

contract ATokenStub is Base, ERC20, ERC20Detailed, AToken {
    using SafeERC20 for IERC20;

    IERC20 public underlying;

    function initialize(address _underlying) public initializer {
        Base.initialize();
        underlying = IERC20(_underlying);
        string memory name = string(abi.encodePacked("Aave Interest bearing ", ERC20Detailed(_underlying).symbol()));
        string memory symbol = string(abi.encodePacked("a", ERC20Detailed(_underlying).symbol()));
        uint8 decimals = ERC20Detailed(_underlying).decimals();
        ERC20Detailed.initialize(name, symbol, decimals);
    }

    function ownerMint(address receiver, uint256 amount) external onlyOwner {
        _mint(receiver, amount);
    }

    function redeem(uint256 amount) external {
        _burnFrom(_msgSender(), amount);
        underlying.safeTransfer(_msgSender(), amount);
    }

}

contract AaveStub is Base, LendingPoolAddressesProvider, Aave {
    using SafeERC20 for IERC20;

    mapping(address=>address) public tokens;

    function initialize() public initializer {
        Base.initialize();
    }

    function createAToken(address _underlying) external onlyOwner {
        ATokenStub aToken = new ATokenStub();
        aToken.initialize(_underlying);
        tokens[_underlying] = address(aToken);
    }


    function deposit(address _reserve, uint256 _amount, uint16 /*_referralCode*/) external {
        address aToken = tokens[_reserve];
        require(aToken != address(0), "Reserve token not supported");
        IERC20(_reserve).safeTransferFrom(_msgSender(), aToken, _amount);
        ATokenStub(aToken).ownerMint(_msgSender(), _amount);
    }

    function getLendingPool() external view returns (address) {
        return address(this);
    }

    function getLendingPoolCore() external view returns (address) {
        return address(this);
    }

}