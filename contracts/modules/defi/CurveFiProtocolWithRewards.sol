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
        uint256 defaultRTCount = defaultRewardTokensCount();
        address[] memory rtokens = new address[](defaultRTCount+2);
        rtokens = defaultRewardTokensFillArray(rtokens);
        rtokens[defaultRTCount] = address(crvToken);
        rtokens[defaultRTCount+1] = address(rewardToken);
        return rtokens;
    }

    function cliamRewardsFromProtocol() internal {
        super.cliamRewardsFromProtocol();
        ICurveFiLiquidityGaugeReward(address(curveFiLPGauge)).claim_rewards();
    }

    uint256[50] private ______gap;
}
