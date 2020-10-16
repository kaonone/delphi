pragma solidity ^0.5.12;

import "../defi/IVaultProtocol.sol";
import "../../modules/token/VaultPoolToken.sol";

//solhint-disable func-order
contract IVaultSavings {
    event VaultRegistered(address protocol, address poolToken);
    event YieldDistribution(address indexed poolToken, uint256 amount);
    event DepositToken(address indexed protocol, address indexed token, uint256 dnAmount);
    event Deposit(address indexed protocol, address indexed user, uint256 nAmount, uint256 nFee);
    event WithdrawToken(address indexed protocol, address indexed token, uint256 dnAmount);
    event Withdraw(address indexed protocol, address indexed user, uint256 nAmount, uint256 nFee);

    function deposit(address[] calldata _protocols, address[] calldata _tokens, uint256[] calldata _dnAmounts) external returns(uint256[] memory);
    function deposit(address _protocol, address[] calldata _tokens, uint256[] calldata _dnAmounts) external returns(uint256);
    function withdraw(address _vaultProtocol, address[] calldata _tokens, uint256[] calldata _amounts, bool isQuick) external returns(uint256);

    function poolTokenByProtocol(address _protocol) external view returns(address);
    function supportedVaults() public view returns(address[] memory);
    function isVaultRegistered(address _protocol) public view returns(bool);

    function registerVault(IVaultProtocol protocol, VaultPoolToken poolToken) external;

    //function quickWithdraw(address _vaultProtocol, address[] calldata _tokens, uint256[] calldata _amounts) external returns(uint256);
    function handleOperatorActions(address _vaultProtocol, address _strategy, address _token) external;

    function claimAllRequested(address _vaultProtocol) external;
}