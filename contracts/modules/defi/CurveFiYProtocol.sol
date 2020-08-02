pragma solidity ^0.5.12;

import "./CurveFiProtocol.sol";
import "../../interfaces/defi/ICurveFiYDeposit.sol";
import "../../interfaces/defi/ICurveFiYRewards.sol";

contract CurveFiYProtocol is CurveFiProtocol {
    uint256 private constant N_COINS = 4;

    function nCoins() internal returns(uint256) {
        return N_COINS;
    }

    function reward_rewardToken(address rewardsController) internal returns(address){
        return ICurveFiYRewards(rewardsController).yfi();
    }

    function convertArray(uint256[] memory amounts) internal pure returns(uint256[4] memory) {
        require(amounts.length == N_COINS, "CurveFiYProtocol: wrong token count");
        uint256[4] memory amnts = [uint256(0), uint256(0), uint256(0), uint256(0)];
        for(uint256 i=0; i < N_COINS; i++){
            amnts[i] = amounts[i];
        }
        return amnts;
    }

    function deposit_add_liquidity(uint256[] memory amounts, uint256 min_mint_amount) internal {
        ICurveFiYDeposit(address(curveFiDeposit)).add_liquidity(convertArray(amounts), min_mint_amount);
    }

    function deposit_remove_liquidity_imbalance(uint256[] memory amounts, uint256 max_burn_amount) internal {
        ICurveFiYDeposit(address(curveFiDeposit)).remove_liquidity_imbalance(convertArray(amounts), max_burn_amount);
    }

}
