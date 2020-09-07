pragma solidity ^0.5.12;

import "../modules/token/PoolToken.sol";

contract PoolToken_Balancer_WETH_WBTC is PoolToken {
    function initialize(address _pool) public initializer {
        PoolToken.initialize(
            _pool, 
            "Delphi Balancer WETH/WBTC",
            "dbWW"
        );
    }    

    // function userBalanceChanged(address account) internal {
    //     IPoolTokenBalanceChangeRecipient investing = IPoolTokenBalanceChangeRecipient(getModuleAddress(MODULE_INVESTING));
    //     investing.poolTokenBalanceChanged(account);
    // }
}
