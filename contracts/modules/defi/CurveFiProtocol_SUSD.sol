pragma solidity ^0.5.12;

import "./CurveFiProtocolWithRewards.sol";
import "../../interfaces/defi/ICurveFiDeposit_SUSD.sol";
import "../../interfaces/defi/ICurveFiLiquidityGaugeReward.sol";

contract CurveFiProtocol_SUSD is CurveFiProtocolWithRewards {
    uint256 private constant N_COINS = 4;


    function nCoins() internal returns(uint256) {
        return N_COINS;
    }

    function convertArray(uint256[] memory amounts) internal pure returns(uint256[N_COINS] memory) {
        require(amounts.length == N_COINS, "CurveFiProtocol_SUSD: wrong token count");
        uint256[N_COINS] memory amnts = [uint256(0), uint256(0), uint256(0), uint256(0)];
        for(uint256 i=0; i < N_COINS; i++){
            amnts[i] = amounts[i];
        }
        return amnts;
    }

    function deposit_add_liquidity(uint256[] memory amounts, uint256 min_mint_amount) internal {
        ICurveFiDeposit_SUSD(address(curveFiDeposit)).add_liquidity(convertArray(amounts), min_mint_amount);
    }

    function deposit_remove_liquidity_imbalance(uint256[] memory amounts, uint256 max_burn_amount) internal {
        ICurveFiDeposit_SUSD(address(curveFiDeposit)).remove_liquidity_imbalance(convertArray(amounts), max_burn_amount);
    }

}
