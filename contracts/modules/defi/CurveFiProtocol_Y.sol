pragma solidity ^0.5.12;

import "./CurveFiProtocol.sol";
import "../../interfaces/defi/ICurveFiDeposit_Y.sol";
import "../../interfaces/defi/IYErc20.sol";

contract CurveFiProtocol_Y is CurveFiProtocol {
    uint256 private constant N_COINS = 4;

    function nCoins() internal returns(uint256) {
        return N_COINS;
    }

    function convertArray(uint256[] memory amounts) internal pure returns(uint256[N_COINS] memory) {
        require(amounts.length == N_COINS, "CurveFiProtocol_Y: wrong token count");
        uint256[N_COINS] memory amnts = [uint256(0), uint256(0), uint256(0), uint256(0)];
        for(uint256 i=0; i < N_COINS; i++){
            amnts[i] = amounts[i];
        }
        return amnts;
    }

    function deposit_add_liquidity(uint256[] memory amounts, uint256 min_mint_amount) internal {
        ICurveFiDeposit_Y(address(curveFiDeposit)).add_liquidity(convertArray(amounts), min_mint_amount);
    }

    function deposit_remove_liquidity_imbalance(uint256[] memory amounts, uint256 max_burn_amount) internal {
        ICurveFiDeposit_Y(address(curveFiDeposit)).remove_liquidity_imbalance(convertArray(amounts), max_burn_amount);
    }


    function balanceOf(address token) public returns(uint256) {
        uint256 tokenIdx = getTokenIndex(token);

        uint256 cfBalance = curveFiTokenBalance();
        uint256 cfTotalSupply = curveFiToken.totalSupply();
        uint256 yTokenCurveFiBalance = curveFiSwap.balances(int128(tokenIdx));
        
        uint256 yTokenShares = yTokenCurveFiBalance.mul(cfBalance).div(cfTotalSupply);
        IYErc20 yToken = IYErc20(curveFiDeposit.coins(int128(tokenIdx)));
        uint256 tokenBalance = yToken.getPricePerFullShare().mul(yTokenShares).div(1e18); //getPricePerFullShare() returns balance of underlying token multiplied by 1e18

        return tokenBalance;
    }
    
    function balanceOfAll() public returns(uint256[] memory balances) {
        IERC20 cfToken = IERC20(curveFiDeposit.token());
        uint256 cfBalance = curveFiTokenBalance();
        uint256 cfTotalSupply = cfToken.totalSupply();

        balances = new uint256[](_registeredTokens.length);
        for (uint256 i=0; i < _registeredTokens.length; i++){
            uint256 ycfBalance = curveFiSwap.balances(int128(i));
            uint256 yShares = ycfBalance.mul(cfBalance).div(cfTotalSupply);
            IYErc20 yToken = IYErc20(curveFiDeposit.coins(int128(i)));
            balances[i] = yToken.getPricePerFullShare().mul(yShares).div(1e18); //getPricePerFullShare() returns balance of underlying token multiplied by 1e18
        }
    }

}
