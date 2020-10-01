pragma solidity ^0.5.12;

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";

import "../interfaces/defi/ICurveFiMinter.sol";
import "../interfaces/defi/ICurveFiLiquidityGauge.sol";

contract CurveFiLiquidityGaugeStub is ICurveFiLiquidityGauge {
    address public minter;
    address public crv_token;
    address public lp_token;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => uint256) public claimable_for;

    function initialize(address lp_addr, address _minter, address _crv_token) public {
        minter = _minter;
        lp_token = lp_addr;

        crv_token =_crv_token;
    }
 
    //Work with LP tokens
    function deposit(uint256 _value) public {

        //self._checkpoint(msg.sender);

        if (_value != 0) {
            uint256 _balance = balanceOf[msg.sender] + _value;
            uint256 _supply = totalSupply + _value;
            balanceOf[msg.sender] = _balance;
            totalSupply = _supply;

            //self._update_liquidity_limit(msg.sender, _balance, _supply);

            IERC20(lp_token).transferFrom(msg.sender, address(this), _value);
        }
    }
    function withdraw(uint256 _value) public {
        //self._checkpoint(msg.sender);

        uint256 _balance = balanceOf[msg.sender] - _value;
        uint256 _supply = totalSupply - _value;
        balanceOf[msg.sender] = _balance;
        totalSupply = _supply;

        //self._update_liquidity_limit(msg.sender, _balance, _supply);

        IERC20(lp_token).transfer(msg.sender, _value);
    }

    //Work with CRV
    function claimable_tokens(address addr) external returns (uint256) {
        //self._checkpoint(addr);
        return claimable_for[addr] - ICurveFiMinter(minter).minted(addr, address(this));
    }

    function set_claimable_for(address addr, uint256 amount) public {
        claimable_for[addr] = amount;
    }
}