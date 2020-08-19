pragma solidity ^0.5.12;

import "./CurveFiProtocol.sol";
import "../../interfaces/defi/ICurveFiLiquidityGaugeReward.sol";

contract CurveFiProtocolWithRewards is CurveFiProtocol {

    address public rewardToken;

    function setCurveFi(address deposit, address liquidityGauge) public onlyDefiOperator {
        super.setCurveFi(deposit, liquidityGauge);
        rewardToken = ICurveFiLiquidityGaugeReward(liquidityGauge).rewarded_token();
    }

    function supportedRewardTokens() public view returns(address[] memory) {
        address[] memory rtokens = new address[](2);
        rtokens[0] = crvToken;
        rtokens[1] = rewardToken;
        return rtokens;
    }

    function isSupportedRewardToken(address token) public view returns(bool) {
        return( 
            (token == crvToken) || 
            (token == rewardToken)
        );
    }

    function cliamRewardsFromProtocol() internal {
        super.cliamRewardsFromProtocol();
        ICurveFiLiquidityGaugeReward(address(curveFiLPGauge)).claim_rewards();
    }

    uint256[50] private ______gap;
}
