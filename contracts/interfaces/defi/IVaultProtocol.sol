pragma solidity ^0.5.12;

import "./IDefiProtocol.sol";

//solhint-disable func-order
contract IVaultProtocol is IDefiProtocol {
    event DepositToVault(address indexed _user, address indexed _token, uint256 _amount);
    event WithdrawFromVault(address indexed _user, address indexed _token, uint256 _amount);

    function depositToVault(address _user, address _token, uint256 _amount) external;
    function depositToVault(address _user, address[] calldata  _tokens, uint256[] calldata _amounts) external;

    function quickWithdraw(address _user, uint256 _amount) external;

    function canWithdrawFromVault(address _user, uint256 _amount) external view returns (bool);
    function requestWithdraw(address _user, uint256 _amount) external;

    function claimRequested(address _user, uint256 _amount) external;
    function canClaimRequested(address _user, uint256 _amount) external view returns (bool);
    function getRequested() external view returns(uint256);

    function withdrawOperator(uint256 _amount) external;
    function depositOperator(uint256 _amount) external;

    function hasOnHoldToken(address _user, address _token) internal view returns (bool, uint256);
    function amountOnHold(address _user, address _token) external view returns (uint256);
}