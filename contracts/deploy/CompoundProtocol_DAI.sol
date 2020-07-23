pragma solidity ^0.5.12;

import "../modules/defi/CompoundProtocol.sol";

contract CompoundProtocol_DAI is CompoundProtocol {
    function initialize(address _pool, address _token, address _cToken) public initializer {
        CompoundProtocol_DAI.initialize(
            _pool, 
            _token,
            _cToken
        );
    }    
}
