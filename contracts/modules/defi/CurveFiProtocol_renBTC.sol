pragma solidity ^0.5.12;

import "./CurveFiProtocol.sol";
import "../../interfaces/defi/ICurveFiSwap_renBTC.sol";

/**
 * @dev CurveFi renBTC Pool does not use Deposit contract, co we have to use Swap directly.
 * To do this we override CurveFiProtocol.setCurveFi()
 */
contract CurveFiProtocol_renBTC is CurveFiProtocol {
    uint256 private constant N_COINS = 2;

    address balRewardToken;

    function nCoins() internal returns(uint256) {
        return N_COINS;
    }

    function setCurveFi(address swap, address liquidityGauge) public onlyDefiOperator {
        // Here we override CurveFiProtocol.setCurveFi()
        if (address(swap) != address(0)) {
            //We need to unregister tokens first
            for (uint256 i=0; i < _registeredTokens.length; i++){
                if (_registeredTokens[i] != address(0)) {
                    _unregisterToken_renBTC(_registeredTokens[i]);
                    _registeredTokens[i] = address(0);
                }
            }
        }
        //curveFiDeposit = ICurveFiDeposit(deposit); //We leave Deposit address uninitialized
        curveFiSwap = ICurveFiSwap(swap);
        curveFiLPGauge = ICurveFiLiquidityGauge(liquidityGauge);

        curveFiToken = IERC20(curveFiLPGauge.lp_token());
        curveFiMinter = ICurveFiMinter(curveFiLPGauge.minter());
        crvToken = curveFiLPGauge.crv_token();

        IERC20(curveFiToken).safeApprove(address(curveFiSwap), MAX_UINT256);
        IERC20(curveFiToken).safeApprove(address(curveFiLPGauge), MAX_UINT256);
        for (uint256 i=0; i < _registeredTokens.length; i++){
            address token = curveFiSwap.coins(int128(i));
            _registerToken_renBTC(token, i);
        }
        emit CurveFiSetup(address(curveFiSwap), address(0), address(curveFiLPGauge));
    }

    function deposit_remove_liquidity_one_coin(uint256 _token_amount, uint256 i, uint256 min_uamount) internal {
        //curveFiDeposit.remove_liquidity_one_coin(_token_amount, int128(i), min_uamount, DONATE_DUST);
        uint256[N_COINS] memory amnts = [uint256(0), uint256(0)];
        amnts[i] = min_uamount;
        ICurveFiSwap_renBTC(address(curveFiSwap)).remove_liquidity_imbalance(amnts, _token_amount);
    }

    function _registerToken_renBTC(address token, uint256 idx) private {
        _registeredTokens[idx] = token;
        IERC20 ltoken = IERC20(token);
        ltoken.safeApprove(address(curveFiSwap), MAX_UINT256);
        // uint256 currentBalance = ltoken.balanceOf(address(this));
        // if (currentBalance > 0) {
        //     handleDeposit(token, currentBalance); 
        // }
        decimals[token] = ERC20Detailed(token).decimals();
        emit TokenRegistered(token);
    }

    function _unregisterToken_renBTC(address token) private {
        uint256 balance = IERC20(token).balanceOf(address(this));

        //TODO: ensure there is no interest on this token which is wating to be withdrawn
        if (balance > 0){
            withdraw(token, _msgSender(), balance);   //This updates withdrawalsSinceLastDistribution
        }
        emit TokenUnregistered(token);
    }




    function convertArray(uint256[] memory amounts) internal pure returns(uint256[N_COINS] memory) {
        require(amounts.length == N_COINS, "CurveFiProtocol_renBTC: wrong token count");
        uint256[N_COINS] memory amnts = [uint256(0), uint256(0)];
        for(uint256 i=0; i < N_COINS; i++){
            amnts[i] = amounts[i];
        }
        return amnts;
    }

    function deposit_add_liquidity(uint256[] memory amounts, uint256 min_mint_amount) internal {
        ICurveFiSwap_renBTC(address(curveFiSwap)).add_liquidity(convertArray(amounts), min_mint_amount);
    }

    function deposit_remove_liquidity_imbalance(uint256[] memory amounts, uint256 max_burn_amount) internal {
        ICurveFiSwap_renBTC(address(curveFiSwap)).remove_liquidity_imbalance(convertArray(amounts), max_burn_amount);
    }

}
