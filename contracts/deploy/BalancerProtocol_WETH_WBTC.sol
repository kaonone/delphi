pragma solidity ^0.5.12;

import "../modules/defi/BalancerProtocol.sol";

contract BalancerProtocol_WETH_WBTC is BalancerProtocol {
    function initialize(address _pool, address _bpt, address _bal) public initializer {
        BalancerProtocol.initialize(_pool);
        setBalancer(_bpt, _bal);
    }    
}
