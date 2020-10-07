pragma solidity ^0.5.12;

import "./ISavingsModule.sol";
import "../defi/IVaultProtocol.sol";
import "../../modules/token/VaultPoolToken.sol";

//solhint-disable func-order
contract IVaultSavings is ISavingsModule {
    function registerVault(IVaultProtocol protocol, VaultPoolToken poolToken) external;

    function quickWithdraw(address _vaultProtocol, address _token, uint256 _amount) external returns(uint256);
    function handleWithdrawRequests(address _vaultProtocol) external;

    function claimAllRequested(address _vaultProtocol) external;
}