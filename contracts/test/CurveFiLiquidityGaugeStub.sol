pragma solidity ^0.5.12;

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";

import "../interfaces/defi/ICurveFiMinter.sol";
import "../interfaces/defi/ICurveFiLiquidityGauge.sol";

contract CurveFiLiquidityGaugeStub is ICurveFiLiquidityGauge {
    using SafeMath for uint256;

    address public minter;
    address public crv_token;
    address public lp_token;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => uint256) public claimable_for;

    //(balance * rate(t) / totalSupply(t) dt) from 0 till checkpoint
    //Units: rate * t = already number of coins per address to issue
    mapping(address => uint256) public _integrate_fraction;

    uint256 public constant BONUS_CRV = 10000000000000000000; //10 CRV with 18 decimals

    function initialize(address lp_addr, address _minter, address _crv_token) public {
        minter = _minter;
        lp_token = lp_addr;

        crv_token =_crv_token;
    }

    function user_checkpoint(address addr) public returns(bool) {
        require(msg.sender == addr || msg.sender == minter, "Unauthirized minter");
        _checkpoint(addr);
        _update_liquidity_limit(addr, balanceOf[addr], totalSupply);
        return true;
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

    function integrate_fraction(address _for) public returns(uint256) {
        return _integrate_fraction[_for];
    }

    function set_claimable_for(address addr, uint256 amount) public {
        claimable_for[addr] = amount;
    }

    function _checkpoint(address addr) internal {
        _integrate_fraction[addr] = _integrate_fraction[addr].add(BONUS_CRV);
        totalSupply = totalSupply.add(BONUS_CRV);
    }

    /**
     * @notice Calculate limits which depend on the amount of CRV token per-user.
                Effectively it calculates working balances to apply amplification
                of CRV production by CRV
     * @param addr User address
     * @param l User's amount of liquidity (LP tokens)
     * @param L Total amount of liquidity (LP tokens)
     */
    function _update_liquidity_limit(address addr, uint256 l, uint256 L) public {
        totalSupply = totalSupply; //prevent state mutability warning;
        addr;
        l;
        L;
    }

}

