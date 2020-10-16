pragma solidity ^0.5.12;

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "../../interfaces/defi/IDefiProtocol.sol";
import "../../interfaces/defi/ICurveFiDeposit.sol";
import "../../interfaces/defi/ICurveFiSwap.sol";
import "../../interfaces/defi/ICurveFiLiquidityGauge.sol";
import "../../interfaces/defi/ICurveFiMinter.sol";
import "./ProtocolBase.sol";


contract CurveFiProtocol is ProtocolBase {
    // Withdrawing one token form Curve.fi pool may lead to small amount of pool token may left unused on Deposit contract. 
    // If DONATE_DUST = true, it will be left there and donated to curve.fi, otherwise we will use gas to transfer it back.
    bool public constant DONATE_DUST = false;    
    uint256 constant MAX_UINT256 = uint256(-1);

    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    event CurveFiSetup(address swap, address deposit, address liquidityGauge);
    event TokenRegistered(address indexed token);
    event TokenUnregistered(address indexed token);

    ICurveFiSwap public curveFiSwap;
    ICurveFiDeposit public curveFiDeposit;
    ICurveFiLiquidityGauge public curveFiLPGauge;
    ICurveFiMinter public curveFiMinter;
    IERC20 public curveFiToken;
    address public crvToken;
    address[] internal _registeredTokens;
    uint256 public slippageMultiplier; //Multiplier to work-around slippage & fees when witharawing one token
    mapping(address => uint8) public decimals;

    function nCoins() internal returns(uint256);
    function deposit_add_liquidity(uint256[] memory amounts, uint256 min_mint_amount) internal;
    function deposit_remove_liquidity_imbalance(uint256[] memory amounts, uint256 max_burn_amount) internal;

    function initialize(address _pool) public initializer {
        ProtocolBase.initialize(_pool);
        _registeredTokens = new address[](nCoins());
        slippageMultiplier = 1.01*1e18;     //Max slippage - 1%, if more - tx will fail
    }

    function setCurveFi(address deposit, address liquidityGauge) public onlyDefiOperator {
        if (address(curveFiDeposit) != address(0)) {
            //We need to unregister tokens first
            for (uint256 i=0; i < _registeredTokens.length; i++){
                if (_registeredTokens[i] != address(0)) {
                    _unregisterToken(_registeredTokens[i]);
                    _registeredTokens[i] = address(0);
                }
            }
        }
        curveFiDeposit = ICurveFiDeposit(deposit);
        curveFiSwap = ICurveFiSwap(curveFiDeposit.curve());
        curveFiToken = IERC20(curveFiDeposit.token());

        curveFiLPGauge = ICurveFiLiquidityGauge(liquidityGauge);
        curveFiMinter = ICurveFiMinter(curveFiLPGauge.minter());
        address lpToken = curveFiLPGauge.lp_token();
        require(lpToken == address(curveFiToken), "CurveFiProtocol: LP tokens do not match");
        crvToken = curveFiLPGauge.crv_token();

        IERC20(curveFiToken).safeApprove(address(curveFiDeposit), MAX_UINT256);
        IERC20(curveFiToken).safeApprove(address(curveFiLPGauge), MAX_UINT256);
        for (uint256 i=0; i < _registeredTokens.length; i++){
            address token = curveFiDeposit.underlying_coins(int128(i));
            _registerToken(token, i);
        }
        emit CurveFiSetup(address(curveFiSwap), address(curveFiDeposit), address(curveFiLPGauge));
    }

    function setSlippageMultiplier(uint256 _slippageMultiplier) public onlyDefiOperator {
        require(_slippageMultiplier >= 1e18, "CurveFiYModule: multiplier should be > 1");
        slippageMultiplier = _slippageMultiplier;
    }

    function handleDeposit(address token, uint256 amount) public onlyDefiOperator {
        uint256[] memory amounts = new uint256[](nCoins());
        for (uint256 i=0; i < _registeredTokens.length; i++){
            amounts[i] = IERC20(_registeredTokens[i]).balanceOf(address(this)); // Check balance which is left after previous withdrawal
            //amounts[i] = (_registeredTokens[i] == token)?amount:0;
            if (_registeredTokens[i] == token) {
                require(amounts[i] >= amount, "CurveFiYProtocol: requested amount is not deposited");
            }
        }
        deposit_add_liquidity(amounts, 0);
        stakeCurveFiToken();
    }

    function handleDeposit(address[] memory tokens, uint256[] memory amounts) public onlyDefiOperator {
        require(tokens.length == amounts.length, "CurveFiYProtocol: count of tokens does not match count of amounts");
        require(amounts.length == nCoins(), "CurveFiYProtocol: amounts count does not match registered tokens");
        uint256[] memory amnts = new uint256[](nCoins());
        for (uint256 i=0; i < _registeredTokens.length; i++){
            uint256 idx = getTokenIndex(tokens[i]);
            amnts[idx] = IERC20(_registeredTokens[idx]).balanceOf(address(this)); // Check balance which is left after previous withdrawal
            require(amnts[idx] >= amounts[i], "CurveFiYProtocol: requested amount is not deposited");
        }
        deposit_add_liquidity(amnts, 0);
        stakeCurveFiToken();
    }

    /** 
    * @dev With this function beneficiary will recieve exact amount he asked. 
    * Slippage + fee is paid from his account in SavingsModule
    */
    function withdraw(address beneficiary, address token, uint256 amount) public onlyDefiOperator {
        uint256 tokenIdx = getTokenIndex(token);
        uint256 available = IERC20(token).balanceOf(address(this));
        if(available < amount) {
            uint256 wAmount = amount.sub(available); //Count tokens left after previous withdrawal

            // count shares for proportional withdraw
            uint256 nAmount = normalizeAmount(token, wAmount);
            uint256 nBalance = normalizedBalance();

            uint256 poolShares = curveFiTokenBalance();
            uint256 withdrawShares = poolShares.mul(nAmount).mul(slippageMultiplier).div(nBalance).div(1e18); //Increase required amount to some percent, so that we definitely have enough to withdraw

            unstakeCurveFiToken(withdrawShares);
            deposit_remove_liquidity_one_coin(withdrawShares, tokenIdx, wAmount);

            available = IERC20(token).balanceOf(address(this));
            require(available >= amount, "CurveFiYProtocol: failed to withdraw required amount");
        }
        IERC20 ltoken = IERC20(token);
        ltoken.safeTransfer(beneficiary, amount);
    }

    function withdraw(address beneficiary, uint256[] memory amounts) public onlyDefiOperator {
        require(amounts.length == nCoins(), "CurveFiYProtocol: wrong amounts array length");

        uint256 nWithdraw;
        uint256[] memory amnts = new uint256[](nCoins());
        uint256 i;
        for (i = 0; i < _registeredTokens.length; i++){
            address tkn = _registeredTokens[i];
            uint256 available = IERC20(tkn).balanceOf(address(this));
            if(available < amounts[i]){
                amnts[i] = amounts[i].sub(available);
            }else{
                amnts[i] = 0;
            }
            nWithdraw = nWithdraw.add(normalizeAmount(tkn, amnts[i]));
        }

        uint256 nBalance = normalizedBalance();
        uint256 poolShares = curveFiTokenBalance();
        uint256 withdrawShares = poolShares.mul(nWithdraw).mul(slippageMultiplier).div(nBalance).div(1e18); //Increase required amount to some percent, so that we definitely have enough to withdraw

        unstakeCurveFiToken(withdrawShares);
        deposit_remove_liquidity_imbalance(amnts, withdrawShares);
        
        for (i = 0; i < _registeredTokens.length; i++){
            IERC20 lToken = IERC20(_registeredTokens[i]);
            uint256 lBalance = lToken.balanceOf(address(this));
            uint256 lAmount = (lBalance <= amounts[i])?lBalance:amounts[i]; // Rounding may prevent Curve.Fi to return exactly requested amount
            lToken.safeTransfer(beneficiary, lAmount);
        }
    }

    function supportedRewardTokens() public view returns(address[] memory) {
        uint256 defaultRTCount = defaultRewardTokensCount();
        address[] memory rtokens = new address[](defaultRTCount+1);
        rtokens = defaultRewardTokensFillArray(rtokens);
        rtokens[defaultRTCount] = address(crvToken);
        return rtokens;
    }

    function cliamRewardsFromProtocol() internal {
        curveFiMinter.mint(address(curveFiLPGauge));
    }

    function balanceOf(address token) public returns(uint256) {
        uint256 tokenIdx = getTokenIndex(token);

        uint256 cfBalance = curveFiTokenBalance();
        uint256 cfTotalSupply = curveFiToken.totalSupply();
        uint256 tokenCurveFiBalance = curveFiSwap.balances(int128(tokenIdx));
        
        return tokenCurveFiBalance.mul(cfBalance).div(cfTotalSupply);
    }
    
    function balanceOfAll() public returns(uint256[] memory balances) {
        uint256 cfBalance = curveFiTokenBalance();
        uint256 cfTotalSupply = curveFiToken.totalSupply();

        balances = new uint256[](_registeredTokens.length);
        for (uint256 i=0; i < _registeredTokens.length; i++){
            uint256 tcfBalance = curveFiSwap.balances(int128(i));
            balances[i] = tcfBalance.mul(cfBalance).div(cfTotalSupply);
        }
    }

    function normalizedBalance() public returns(uint256) {
        uint256[] memory balances = balanceOfAll();
        uint256 summ;
        for (uint256 i=0; i < _registeredTokens.length; i++){
            summ = summ.add(normalizeAmount(_registeredTokens[i], balances[i]));
        }
        return summ;
    }

    function optimalProportions() public returns(uint256[] memory) {
        uint256[] memory amounts = balanceOfAll();
        uint256 summ;
        for (uint256 i=0; i < _registeredTokens.length; i++){
            amounts[i] = normalizeAmount(_registeredTokens[i], amounts[i]);
            summ = summ.add(amounts[i]);
        }
        for (uint256 i=0; i < _registeredTokens.length; i++){
            amounts[i] = amounts[i].div(summ);
        }
        return amounts;
    }
    

    function supportedTokens() public view returns(address[] memory){
        return _registeredTokens;
    }

    function supportedTokensCount() public view returns(uint256) {
        return _registeredTokens.length;
    }

    function getTokenIndex(address token) public view returns(uint256) {
        for (uint256 i=0; i < _registeredTokens.length; i++){
            if (_registeredTokens[i] == token){
                return i;
            }
        }
        revert("CurveFiYProtocol: token not registered");
    }

    function canSwapToToken(address token) public view returns(bool) {
        for (uint256 i=0; i < _registeredTokens.length; i++){
            if (_registeredTokens[i] == token){
                return true;
            }
        }
        return false;
    }

    function deposit_remove_liquidity_one_coin(uint256 _token_amount, uint256 i, uint256 min_uamount) internal {
        curveFiDeposit.remove_liquidity_one_coin(_token_amount, int128(i), min_uamount, DONATE_DUST);
    }

    function normalizeAmount(address token, uint256 amount) internal view returns(uint256) {
        uint256 _decimals = uint256(decimals[token]);
        if (_decimals == 18) {
            return amount;
        } else if (_decimals > 18) {
            return amount.div(10**(_decimals-18));
        } else if (_decimals < 18) {
            return amount.mul(10**(18-_decimals));
        }
    }

    function denormalizeAmount(address token, uint256 amount) internal view returns(uint256) {
        uint256 _decimals = uint256(decimals[token]);
        if (_decimals == 18) {
            return amount;
        } else if (_decimals > 18) {
            return amount.mul(10**(_decimals-18));
        } else if (_decimals < 18) {
            return amount.div(10**(18-_decimals));
        }
    }

    function curveFiTokenBalance() internal view returns(uint256) {
        uint256 notStaked = curveFiToken.balanceOf(address(this));
        uint256 staked = curveFiLPGauge.balanceOf(address(this));
        return notStaked.add(staked);
    }

    function stakeCurveFiToken() internal {
        uint256 cftBalance = curveFiToken.balanceOf(address(this));
        curveFiLPGauge.deposit(cftBalance);
    }

    function unstakeCurveFiToken(uint256 amount) internal {
        curveFiLPGauge.withdraw(amount);
    }

    function _registerToken(address token, uint256 idx) private {
        _registeredTokens[idx] = token;
        IERC20 ltoken = IERC20(token);
        ltoken.safeApprove(address(curveFiDeposit), MAX_UINT256);
        // uint256 currentBalance = ltoken.balanceOf(address(this));
        // if (currentBalance > 0) {
        //     handleDeposit(token, currentBalance); 
        // }
        decimals[token] = ERC20Detailed(token).decimals();
        emit TokenRegistered(token);
    }

    function _unregisterToken(address token) private {
        uint256 balance = IERC20(token).balanceOf(address(this));

        //TODO: ensure there is no interest on this token which is wating to be withdrawn
        if (balance > 0){
            withdraw(token, _msgSender(), balance);   //This updates withdrawalsSinceLastDistribution
        }
        emit TokenUnregistered(token);
    }

    uint256[50] private ______gap;
}
