pragma solidity ^0.5.12;

import "../modules/token/PoolToken.sol";
import "../interfaces/token/IPoolTokenBalanceChangeRecipient.sol";

contract PoolToken_CurveFi_SBTC is PoolToken {
    function initialize(address _pool) public initializer {
        PoolToken.initialize(
            _pool, 
            "Delphi Curve sBTC",
            "dsBTC"
        );
    }
}
