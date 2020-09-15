pragma solidity ^0.5.12;

import "./IDefiProtocol.sol";

//solhint-disable func-order
contract IVaultProtocol is IDefiProtocol { 
    function quickWithdraw(address _user, uint256 _amount) external;

    function canWithdrawFromVault(address _user, uint256 _amount) external view returns (bool);
    function requestWithdraw(address _user, uint256 _amount) external;

    function claimRequested(address _user, uint256 _amount) external;
    function canClaimRequested(address _user, uint256 _amount) external view returns (bool);
    function getRequested() external view returns(uint256);

    function withdrawOperator(uint256 _amount) external;
    function depositOperator(uint256 _amount) external;
}