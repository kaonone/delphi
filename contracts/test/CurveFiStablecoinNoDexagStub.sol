pragma solidity ^0.5.12;

import "../modules/defi/CurveFiStablecoinStrategy.sol";

contract CurveFiStablecoinNoDexag is CurveFiStablecoinStrategy {
    address public dexagStub;

    function initialize(address _pool, string memory _strategyId, address _dexagStub) public initializer {
        CurveFiStablecoinStrategy.initialize(_pool, _strategyId);

        dexagStub = _dexagStub;
    }

    function performStrategyStep2NoDexag(address swapStablecoin) public {
        uint256 crvAmount = IERC20(crvToken).balanceOf(address(this));
        IERC20(crvToken).transfer(dexagStub, crvAmount);

        IERC20(swapStablecoin).transferFrom(dexagStub, address(this), crvAmount.div(2));

        uint256 amount = IERC20(swapStablecoin).balanceOf(address(this));
        IERC20(swapStablecoin).transfer(vault, amount);
    }
}