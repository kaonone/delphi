pragma solidity ^0.5.12;

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Mintable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Burnable.sol";
import "../common/Base.sol";


contract CurveFiTokenStub_SUSD is Base, ERC20, ERC20Detailed, ERC20Mintable, ERC20Burnable {
    function initialize() public initializer {
        Base.initialize();
        ERC20Mintable.initialize(_msgSender());
        ERC20Detailed.initialize("Curve.fi DAI/USDC/USDT/sUSD", "crvPlain3andSUSD", 18);
    }
}