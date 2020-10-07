pragma solidity ^0.5.12;

//solhint-disable func-order
contract IVaultProtocol {
    event DepositToVault(address indexed _user, address indexed _token, uint256 _amount);
    event WithdrawFromVault(address indexed _user, address indexed _token, uint256 _amount);
    event WithdrawRequestCreated(address indexed _user, address indexed _token, uint256 _amount);
    event DepositByOperator(uint256 _amount);
    event WithdrawByOperator(uint256 _amount);
    event WithdrawRequestsResolved(uint256 _totalDeposit, uint256 _totalWithdraw);

    function supportedTokens() external view returns(address[] memory);
    function supportedTokensCount() external view returns(uint256);
    function tokenRegisteredInd(address _token) external view returns(uint256);

    function normalizedBalance() external returns(uint256);

    function registerStrategy(address _strategy) external;

    function depositToVault(address _user, address _token, uint256 _amount) external;
    function depositToVault(address _user, address[] calldata  _tokens, uint256[] calldata _amounts) external;

    function withdrawFromVault(address _user, address _token, uint256 _amount) external;
    function withdrawFromVault(address _user, address[] calldata  _tokens, uint256[] calldata _amounts) external;

    function withdrawOperator() external returns(uint256, uint256);

        function quickWithdraw(address _user, uint256 _amount) external;

    function claimRequested(address _user) external;
    function claimableAmount(address _user, address _token) external view returns (uint256);

    function amountOnHold(address _user, address _token) external view returns (uint256);
    function hasOnHoldToken(address _user, address _token) internal view returns (bool, uint256);

    function amountRequested(address _user, address _token) external view returns (uint256);
    function hasRequestedToken(address _user, address _token) internal view returns (bool, uint256);
}