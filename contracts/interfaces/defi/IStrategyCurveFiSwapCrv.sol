pragma solidity ^0.5.12;

interface IStrategyCurveFiSwapCrv {
    event CrvClaimed(string indexed id, address strategy, uint256 amount);

    function curveFiTokenBalance() external view returns(uint256);
    function performStrategyStep1() external;
    function performStrategyStep2(bytes calldata _data, address _token) external;
}
