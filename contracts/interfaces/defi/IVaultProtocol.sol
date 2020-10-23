pragma solidity ^0.5.12;

//solhint-disable func-order
contract IVaultProtocol {
    event DepositToVault(address indexed _user, address indexed _token, uint256 _amount);
    event WithdrawFromVault(address indexed _user, address indexed _token, uint256 _amount);
    event WithdrawRequestCreated(address indexed _user, address indexed _token, uint256 _amount);
    event DepositByOperator(uint256 _amount);
    event WithdrawByOperator(uint256 _amount);
    event WithdrawRequestsResolved(uint256 _totalDeposit, uint256 _totalWithdraw);
    event StrategyRegistered(address indexed _vault, address indexed _strategy, string _id);

    event Claimed(address indexed _vault, address indexed _user, address _token, uint256 _amount);
    event DepositsCleared(address indexed _vault);
    event RequestsCleared(address indexed _vault);


    function registerStrategy(address _strategy) external;

    function depositToVault(address _user, address _token, uint256 _amount) external;
    function depositToVault(address _user, address[] calldata  _tokens, uint256[] calldata _amounts) external;

    function withdrawFromVault(address _user, address _token, uint256 _amount) external;
    function withdrawFromVault(address _user, address[] calldata  _tokens, uint256[] calldata _amounts) external;

    function operatorAction(address _strategy) external returns(uint256, uint256);
    function operatorActionOneCoin(address _strategy, address _token) external returns(uint256, uint256);
    function clearOnHoldDeposits() external;
    function clearWithdrawRequests() external;
    function setRemainder(uint256 _amount, uint256 _index) external;

    function quickWithdraw(address _user, address[] calldata _tokens, uint256[] calldata _amounts) external;
    function quickWithdrawStrategy() external view returns(address);

    function claimRequested(address _user) external;

    function normalizedBalance() external returns(uint256);
    function normalizedBalance(address _strategy) external returns(uint256);
    function normalizedVaultBalance() external view returns(uint256);

    function supportedTokens() external view returns(address[] memory);
    function supportedTokensCount() external view returns(uint256);

    function isStrategyRegistered(address _strategy) external view returns(bool);
    function registeredStrategies() external view returns(address[] memory);

    function isTokenRegistered(address _token) external view returns (bool);
    function tokenRegisteredInd(address _token) external view returns(uint256);

    function totalClaimableAmount(address _token) external view returns (uint256);
    function claimableAmount(address _user, address _token) external view returns (uint256);

    function amountOnHold(address _user, address _token) external view returns (uint256);

    function amountRequested(address _user, address _token) external view returns (uint256);
}