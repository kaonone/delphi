pragma solidity ^0.5.12;

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "../interfaces/defi/ICurveFiSwap_SUSD.sol";
import "../interfaces/defi/ICurveFiDeposit_SUSD.sol";
import "../common/Base.sol";
import "./CurveFiSwapStub_SUSD.sol";

contract CurveFiDepositStub_SUSD is Base, ICurveFiDeposit_SUSD {
    using SafeMath for uint256;
    uint256 constant EXP_SCALE = 1e18;  //Exponential scale (see Compound Exponential)
    uint256 public constant N_COINS = 4;
    uint256 constant MAX_UINT256 = uint256(-1);

    CurveFiSwapStub_SUSD public curveFiSwap;
    IERC20 public token;
    address[N_COINS] _coins;
    address[N_COINS] underlying;

    function initialize(address _curveFiSwap) public initializer {
        Base.initialize();
        curveFiSwap = CurveFiSwapStub_SUSD(_curveFiSwap);
        token = IERC20(curveFiSwap.token());
        for (uint256 i=0; i < N_COINS; i++){
            _coins[i] = curveFiSwap.coins(int128(i));
            underlying[i] = _coins[i]; //IYErc20(_coins[i]).token();
            IERC20(_coins[i]).approve(_curveFiSwap, MAX_UINT256);
        }
    }

    function add_liquidity (uint256[N_COINS] memory uamounts, uint256 min_mint_amount) public {
        uint256[N_COINS] memory amounts = [uint256(0), uint256(0), uint256(0), uint256(0)];
        for (uint256 i=0; i < uamounts.length; i++){
            require(IERC20(underlying[i]).transferFrom(_msgSender(), address(this), uamounts[i]), "CurveFiDepositStub: failed to transfer underlying");
            //IYErc20(_coins[i]).deposit(uamounts[i]);
            //amounts[i] = IYErc20(_coins[i]).balanceOf(address(this));
            amounts[i] = IERC20(_coins[i]).balanceOf(address(this));
            IERC20(_coins[i]).approve(address(curveFiSwap), MAX_UINT256);
        }
        curveFiSwap.add_liquidity(amounts, min_mint_amount);
        uint256 shares = token.balanceOf(address(this));
        token.transfer(_msgSender(), shares);
    }
    
    function remove_liquidity (uint256 _amount, uint256[N_COINS] memory min_uamounts) public {
        token.transferFrom(_msgSender(), address(this), _amount);
        curveFiSwap.remove_liquidity(_amount, [uint256(0), uint256(0), uint256(0), uint256(0)]);
        send_all(_msgSender(), min_uamounts);
    }

    function remove_liquidity_imbalance (uint256[N_COINS] memory uamounts, uint256 max_burn_amount) public {
        uint256[N_COINS] memory amounts = [uint256(0), uint256(0), uint256(0), uint256(0)];
        for (uint256 i=0; i < uamounts.length; i++){
            //amounts[i] = uamounts[i];.mul(EXP_SCALE).div(IYErc20(_coins[i]).getPricePerFullShare());
            amounts[i] = uamounts[i];
        }

        uint256 shares = token.balanceOf(_msgSender());
        if (shares > max_burn_amount) shares = max_burn_amount;

        token.transferFrom(_msgSender(), address(this), shares);
        curveFiSwap.remove_liquidity_imbalance(amounts, shares);

        shares = token.balanceOf(_msgSender());
        token.transfer(_msgSender(), shares); // Return unused
        send_all(_msgSender(), [uint256(0), uint256(0), uint256(0), uint256(0)]);
    }

    function remove_liquidity_one_coin(uint256 _token_amount, int128 i, uint256 min_uamount) public {
        remove_liquidity_one_coin(_token_amount, i, min_uamount, false);
    }

    function remove_liquidity_one_coin(uint256 _token_amount, int128 _i, uint256 min_uamount, bool donate_dust) public {
        uint256[N_COINS] memory amounts = [uint256(0), uint256(0), uint256(0), uint256(0)];
        uint256 i = uint256(_i);
        //amounts[i] = min_uamount.mul(EXP_SCALE).div(IYErc20(_coins[i]).getPricePerFullShare());
        amounts[i] = min_uamount;
        curveFiSwap.remove_liquidity_imbalance(amounts, _token_amount);

        uint256[N_COINS] memory uamounts = [uint256(0), uint256(0), uint256(0), uint256(0)];
        uamounts[i] = min_uamount;
        send_all(_msgSender(), uamounts);
        if (!donate_dust) {
            uint256 shares = token.balanceOf(address(this));
            token.transfer(_msgSender(), shares);
        }
    }

    function withdraw_donated_dust() public onlyOwner {
        uint256 shares = token.balanceOf(address(this));
        token.transfer(owner(), shares);
    }

    function coins(int128 i) public view returns (address) {
        return _coins[uint256(i)];
    }

    function underlying_coins(int128 i) public view returns (address) {
        return underlying[uint256(i)];
    }

    function curve() public view returns (address) {
        return address(curveFiSwap);
    }

    function calc_withdraw_one_coin (uint256 _token_amount, int128 i) public view returns (uint256) {
        this;
        return uint256(0).mul(_token_amount.mul(uint256(i))); //we do not use this
    }

    function send_all(address beneficiary, uint256[N_COINS] memory min_uamounts) internal {
        for (uint256 i=0; i < _coins.length; i++){
            //uint256 shares = IYErc20(_coins[i]).balanceOf(address(this));
            uint256 shares = IERC20(_coins[i]).balanceOf(address(this));
            if (shares == 0){
                require(min_uamounts[i] == 0, "CurveFiDepositStub: nothing to withdraw");
                continue;
            }
            //IYErc20(_coins[i]).withdraw(shares);
            uint256 uamount = IERC20(underlying[i]).balanceOf(address(this));
            require(uamount >= min_uamounts[i], "CurveFiDepositStub: requested amount is too high");
            if (uamount > 0) {
                IERC20(underlying[i]).transfer(beneficiary, uamount);
            }
        }        
    }
}