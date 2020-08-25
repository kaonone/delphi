pragma solidity ^0.5.12;

import "./CurveFiProtocol_Y_Base.sol";
import "../../interfaces/defi/ICurveFiDeposit_Y.sol";

contract CurveFiProtocol_Y is CurveFiProtocol_Y_Base {
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

}
