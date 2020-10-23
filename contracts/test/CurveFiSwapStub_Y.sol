pragma solidity ^0.5.12;

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Mintable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Burnable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "../interfaces/defi/IYErc20.sol";
import "../interfaces/defi/ICurveFiSwap.sol";
import "../interfaces/defi/ICurveFiSwap_Y.sol";
import "../common/Base.sol";
import "./CurveFiTokenStub_Y.sol";

contract CurveFiSwapStub_Y is Base, ICurveFiSwap, ICurveFiSwap_Y {
    using SafeMath for uint256;
    uint256 public constant N_COINS = 4;
    uint256 constant MAX_EXCHANGE_FEE = 0.05*1e18;

    CurveFiTokenStub_Y public token;
    address[N_COINS] _coins;

    function initialize(address[N_COINS] memory __coins) public initializer {
        Base.initialize();
        _coins = __coins;
        token = deployToken();
    }

    function add_liquidity (uint256[N_COINS] memory amounts, uint256 min_mint_amount) public {
        uint256 fullAmount;

        for (uint256 i=0; i < N_COINS; i++){
            IERC20(_coins[i]).transferFrom(_msgSender(), address(this), amounts[i]);
            fullAmount = fullAmount.add(normalizeAmount(_coins[i], amounts[i]));
        }
        (uint256 fee, bool bonus) = calculateExchangeFee(amounts, false);
        if (bonus) {
            fullAmount = fullAmount.add(fee);
        } else {
            fullAmount = fullAmount.sub(fee);
        }
        require(fullAmount >= min_mint_amount, "CurveFiSwapStub: Requested mint amount is too high");
        require(token.mint(_msgSender(), fullAmount), "CurveFiSwapStub: Mint failed");
    }

    function remove_liquidity (uint256 _amount, uint256[N_COINS] memory min_amounts) public {
        uint256 totalSupply = token.totalSupply();
        uint256[] memory amounts = new uint256[](_coins.length);
        for (uint256 i=0; i < _coins.length; i++){
            uint256 balance = balances(int128(i));
            amounts[i] = _amount.mul(balance).div(totalSupply);
            require(amounts[i] >= min_amounts[i], "CurveFiSwapStub: Requested amount is too high");
            IERC20(_coins[i]).transfer(_msgSender(), amounts[i]);
        }
        token.burnFrom(_msgSender(), _amount);
    }

    function remove_liquidity_imbalance(uint256[N_COINS] memory amounts, uint256 max_burn_amount) public {
        uint256 fullAmount = calc_token_amount(amounts, false);
        for (uint256 i=0; i < _coins.length; i++){
            IERC20(_coins[i]).transfer(_msgSender(), amounts[i]);
        }
        require(max_burn_amount == 0 || fullAmount <= max_burn_amount, "CurveFiSwapStub: Allowed burn amount is not enough");
        token.burnFrom(_msgSender(), fullAmount);
    }

    function calc_token_amount(uint256[N_COINS] memory amounts, bool deposit) public view returns(uint256) {
        (uint256 fee, bool bonus) = calculateExchangeFee(amounts, deposit);
        uint256 fullAmount;
        for (uint256 i=0; i < _coins.length; i++){
            uint256 balance = balances(int128(i));
            require(balance >= amounts[i], "CurveFiSwapStub: Not enough supply");
            fullAmount = fullAmount.add(normalizeAmount(_coins[i], amounts[i]));
        }
        if (bonus) {
            fullAmount = fullAmount.sub(fee);
        } else {
            fullAmount = fullAmount.add(fee);
        }
        return fullAmount;
    }

    function balances(int128 i) public view returns(uint256) {
        return IERC20(_coins[uint256(i)]).balanceOf(address(this));
    }

    function A() public view returns(uint256) {
        this;
        return 0;
    }

    function fee() public view returns(uint256) {
        this;
        return 0;
    }

    function coins(int128 i) public view returns (address) {
        return _coins[uint256(i)];
    }

    function deployToken() internal returns(CurveFiTokenStub_Y){ 
        CurveFiTokenStub_Y tkn = new CurveFiTokenStub_Y();
        tkn.initialize();
        return tkn;
    }    

    function calculateExchangeFee(uint256[N_COINS] memory diff, bool deposit) internal view returns(uint256 fullFee, bool bonus){
        uint256 averageAmount = 0;
        uint256[] memory _balances = new uint256[](_coins.length);
        for (uint256 i=0; i < _coins.length; i++){
            _balances[i] = balances(int128(i));
            averageAmount = averageAmount.add(normalizeAmount(_coins[i], _balances[i]));
        }
        averageAmount = averageAmount.div(_coins.length);
        int256 totalFee;
        for (uint256 i=0; i < _coins.length; i++){
            int256 oldDiff = int256(_balances[i]) - int256(averageAmount);
            int256 newDiff;
            if (deposit) {
                newDiff = oldDiff + int256(diff[i]);
            } else {
                newDiff = oldDiff - int256(diff[i]);
            }
             

            uint256 maxFee = diff[i].mul(MAX_EXCHANGE_FEE).div(1e18);
            int256 _fee;
            if (oldDiff == 0) {
                _fee = 0;
            } else {
                if (deposit){
                    _fee = int256(MAX_EXCHANGE_FEE)*int256(diff[i]) / oldDiff;
                } else {
                    _fee = -1*int256(MAX_EXCHANGE_FEE)*int256(diff[i]) / oldDiff;
                }
            }
            if (_fee > 0 && _fee > int256(maxFee)) _fee = int256(maxFee);
            if (_fee < 0 && -1*_fee > int256(maxFee)) _fee = -1*int256(maxFee);
            totalFee += _fee;
        }
        if (totalFee < 0){
            bonus = true;
            fullFee = uint256(-1*totalFee);
        } else {
            bonus = false;
            fullFee = uint256(totalFee);
        }
    }

    function normalizeAmount(address coin, uint256 amount) internal view returns(uint256){
        uint8 decimals = ERC20Detailed(coin).decimals();
        if (decimals < 18) {
            return amount * uint256(10)**(18-decimals);
        } else if (decimals > 18) {
            return amount / uint256(10)**(decimals-18);
        } else {
            return amount;
        }
    }
}