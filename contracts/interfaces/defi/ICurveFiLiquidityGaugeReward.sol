pragma solidity ^0.5.16;

interface ICurveFiLiquidityGaugeReward {
    function rewarded_token() external returns(address);
    function withdraw(uint256 _value, bool claim_rewards) external;
    function claim_rewards() external;
}