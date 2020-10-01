pragma solidity ^0.5.12;

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Mintable.sol";

import "../interfaces/defi/ICurveFiMinter.sol";
import "../interfaces/defi/ICurveFiLiquidityGauge.sol";

contract CurveFiMinterStub is ICurveFiMinter {
    mapping(address => mapping(address => uint256)) public minted_for;
    address public token;

    function initialize(address _crvToken) public {
        token = _crvToken;
    }

    function mint(address gauge_addr) public {
        address _for = msg.sender;

        //ICurveFiLiquidityGauge(gauge_addr).user_checkpoint(_for);
        uint256 total_mint = ICurveFiLiquidityGauge(gauge_addr).balanceOf(_for);
        uint256 to_mint = total_mint - minted_for[_for][gauge_addr];

        if (to_mint != 0) {
            ERC20Mintable(token).mint(_for, to_mint);
            minted_for[_for][gauge_addr] = total_mint;
        }

    }

    function minted(address _for, address gauge_addr) public returns(uint256) {
        return minted_for[_for][gauge_addr];
    }
}