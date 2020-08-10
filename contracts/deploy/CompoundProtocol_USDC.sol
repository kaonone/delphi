pragma solidity ^0.5.12;

import "../modules/defi/CompoundProtocol.sol";

contract CompoundProtocol_USDC is CompoundProtocol {
    function initialize(address _pool, address _token, address _cToken, address _comptroller) public initializer {
        CompoundProtocol.initialize(
            _pool, 
            _token,
            _cToken,
            _comptroller
        );
    }    
}
