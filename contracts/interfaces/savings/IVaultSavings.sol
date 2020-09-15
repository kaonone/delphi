pragma solidity ^0.5.12;

import "./ISavingsModule.sol";
import "../defi/IVaultProtocol.sol";

//solhint-disable func-order
contract IVaultSavings is ISavingsModule {
    function quickWithdraw(address _vaultProtocol, address token, uint256 dnAmount, uint256 maxNAmount) external returns(uint256);
    function handleWithdrawRequests(address _vaultProtocol) external;
    function handleDeposits(address _vaultProtocol) external;
}