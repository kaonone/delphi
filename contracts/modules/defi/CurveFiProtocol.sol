pragma solidity ^0.5.12;

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "../../interfaces/defi/IDefiProtocol.sol";
import "../../interfaces/defi/ICurveFiDeposit.sol";
import "../../interfaces/defi/ICurveFiSwap.sol";
import "../../interfaces/defi/ICurveFiRewards.sol";
import "./ProtocolBase.sol";


contract CurveFiProtocol is ProtocolBase {
    // Withdrawing one token form Curve.fi pool may lead to small amount of pool token may left unused on Deposit contract. 
    // If DONATE_DUST = true, it will be left there and donated to curve.fi, otherwise we will use gas to transfer it back.
    bool public constant DONATE_DUST = true;    
    uint256 constant MAX_UINT256 = uint256(-1);

    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    event CurveFiSetup(address swap, address deposit, address rewardsController);
    event TokenRegistered(address indexed token);
    event TokenUnregistered(address indexed token);

    ICurveFiSwap public curveFiSwap;
    ICurveFiDeposit public curveFiDeposit;
    ICurveFiRewards public curveFiRewards;
    IERC20 public curveFiRewardToken;
    IERC20 public curveFiToken;
    address[] internal _registeredTokens;
    uint256 public slippageMultiplier; //Multiplier to work-around slippage & fees when witharawing one token
    mapping(address => uint8) public decimals;

    function nCoins() internal returns(uint256);
    function deposit_add_liquidity(uint256[] memory amounts, uint256 min_mint_amount) internal;
    function deposit_remove_liquidity_imbalance(uint256[] memory amounts, uint256 max_burn_amount) internal;
    function reward_rewardToken(address rewardsController) internal returns(address);

    function initialize(address _pool) public initializer {
        ProtocolBase.initialize(_pool);
        _registeredTokens = new address[](nCoins());
        slippageMultiplier = 1.01*1e18;     //Max slippage - 1%, if more - tx will fail
    }

    function setCurveFi(address deposit, address rewardsController) public onlyDefiOperator {
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
        curveFiRewards = ICurveFiRewards(rewardsController);
        curveFiRewardToken = IERC20(reward_rewardToken(rewardsController));
        IERC20(curveFiToken).safeApprove(address(curveFiDeposit), MAX_UINT256);
        IERC20(curveFiToken).safeApprove(address(curveFiRewards), MAX_UINT256);
        for (uint256 i=0; i < _registeredTokens.length; i++){
            address token = curveFiDeposit.underlying_coins(int128(i));
            _registeredTokens[i] = token;
            _registerToken(token);
            IERC20(token).safeApprove(address(curveFiDeposit), MAX_UINT256);
        }
        emit CurveFiSetup(address(curveFiSwap), address(curveFiDeposit), address(curveFiRewards));
    }

    function setSlippageMultiplier(uint256 _slippageMultiplier) public onlyDefiOperator {
        require(_slippageMultiplier >= 1e18, "CurveFiYModule: multiplier should be > 1");
        slippageMultiplier = _slippageMultiplier;
    }

    function handleDeposit(address, address token, uint256 amount) public onlyDefiOperator {
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

    function handleDeposit(address, address[] memory tokens, uint256[] memory amounts) public onlyDefiOperator {
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
        uint256 wAmount = amount.sub(available); //Count tokens left after previous withdrawal

        // count shares for proportional withdraw
        uint256 nAmount = normalizeAmount(token, wAmount);
        uint256 nBalance = normalizedBalance();

        uint256 poolShares = curveFiTokenBalance();
        uint256 withdrawShares = poolShares.mul(nAmount).mul(slippageMultiplier).div(nBalance).div(1e18); //Increase required amount to some percent, so that we definitely have enough to withdraw

        unstakeCurveFiToken(withdrawShares);
        curveFiDeposit.remove_liquidity_one_coin(withdrawShares, int128(tokenIdx), wAmount, DONATE_DUST);

        available = IERC20(token).balanceOf(address(this));
        require(available >= amount, "CurveFiYProtocol: failed to withdraw required amount");
        IERC20 ltoken = IERC20(token);
        ltoken.safeTransfer(beneficiary, amount);
    }

    function withdraw(address beneficiary, uint256[] memory amounts) public onlyDefiOperator {
        require(amounts.length == nCoins(), "CurveFiYProtocol: wrong amounts array length");
        uint256[] memory amnts = new uint256[](nCoins());
        uint256 i;
        for (i = 0; i < _registeredTokens.length; i++){
            amnts[i] = amounts[i];
        }
        unstakeCurveFiToken();
        deposit_remove_liquidity_imbalance(amnts, MAX_UINT256);
        stakeCurveFiToken();
        for (i = 0; i < _registeredTokens.length; i++){
            IERC20 ltoken = IERC20(_registeredTokens[i]);
            ltoken.safeTransfer(beneficiary, amounts[i]);
        }
    }

    function supportedRewardTokens() public view returns(address[] memory) {
        address[] memory rtokens = new address[](1);
        rtokens[0] = address(curveFiRewardToken);
        return rtokens;
    }

    function isSupportedRewardToken(address token) public view returns(bool) {
        return(token == address(curveFiRewardToken));
    }

    function cliamRewardsFromProtocol() internal {
        curveFiRewards.getReward();
    }

    function balanceOf(address token) public returns(uint256) {
        uint256 tokenIdx = getTokenIndex(token);

        uint256 cfBalance = curveFiTokenBalance();
        uint256 cfTotalSupply = curveFiToken.totalSupply();
        uint256 tokenCurveFiBalance = curveFiSwap.balances(int128(tokenIdx));
        
        return tokenCurveFiBalance.mul(cfBalance).div(cfTotalSupply);
    }
    
    function balanceOfAll() public returns(uint256[] memory balances) {
        IERC20 cfToken = IERC20(curveFiDeposit.token());
        uint256 cfBalance = curveFiRewards.balanceOf(address(this));
        uint256 cfTotalSupply = cfToken.totalSupply();

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
        return curveFiRewards.balanceOf(address(this));
    }

    function stakeCurveFiToken() private {
        uint256 cftBalance = curveFiToken.balanceOf(address(this));
        curveFiRewards.stake(cftBalance);
    }

    function unstakeCurveFiToken(uint256 amount) private {
        curveFiRewards.withdraw(amount);
    }

    function unstakeCurveFiToken() private {
        uint256 balance = curveFiRewards.balanceOf(address(this));
        curveFiRewards.withdraw(balance);
    }

    function _registerToken(address token) private {
        IERC20 ltoken = IERC20(token);
        uint256 currentBalance = ltoken.balanceOf(address(this));
        if (currentBalance > 0) {
            handleDeposit(address(this), token, currentBalance); 
        }
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

}
