pragma solidity ^0.5.12;

import "../modules/defi/AaveProtocol.sol";

contract AaveProtocol_USDT is AaveProtocol {
    function initialize(address _pool, address _token, address aaveAddressProvider, uint16 _aaveReferralCode) public initializer {
        AaveProtocol.initialize(
            _pool, 
            _token,
            aaveAddressProvider,
            _aaveReferralCode
        );
    }    
}
