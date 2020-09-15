pragma solidity ^0.5.12;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/SafeERC20.sol";
import "../../interfaces/defi/IVaultProtocol.sol";
import "../../interfaces/savings/IVaultSavings.sol";
import "../../common/Module.sol";
import "../defi/DefiOperatorRole.sol";
//import "../access/AccessChecker.sol";
import "./RewardDistributions.sol";
//import "./SavingsCap.sol";

contract VaultSavingsModule is Module, IVaultSavings, RewardDistributions, DefiOperatorRole{ //}, AccessChecker, SavingsCap {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    function initialize(address _pool) public initializer {
        Module.initialize(_pool);
        DefiOperatorRole.initialize(_msgSender());
//        SavingsCap.initialize(_msgSender());
    }


// Inherited from ISavingsModule
    function registerProtocol(IDefiProtocol protocol, PoolToken poolToken) public onlyOwner {
        //stab
    }


    function deposit(address[] memory _protocols, address[] memory _tokens, uint256[] memory _dnAmounts) 
    public //operationAllowed(IAccessModule.Operation.Deposit) 
    returns(uint256[] memory) 
    {
         //stab
        uint256[] memory ptAmounts = new uint256[](_protocols.length);
        //stab
       
        //The same logic as for SavingsModule

        return ptAmounts;
    }


    function deposit(address _protocol, address[] memory _tokens, uint256[] memory _dnAmounts)
    public //operationAllowed(IAccessModule.Operation.Deposit)
    returns(uint256) 
    {
        //stab

        //Tokens are transferred to the VaultProtocol adapter.
        //Pool tokens are minted instead for the sender

        return 0;
    }

    function withdraw(address _protocol, address token, uint256 dnAmount, uint256 maxNAmount)
    public //operationAllowed(IAccessModule.Operation.Withdraw)
    returns(uint256)
    {
        //stab

        //if VaultProtocol adapter has sufficient amount of tokens
        //      direct transfer from VaultProtocol.withdraw()
        //if not - create a request from the protocol VaultProtocol.requestWithdraw()
        
        return 0;
    }

    /** 
     * @notice Distributes yield. May be called by bot, if there was no deposits/withdrawals
     */
    function distributeYield() public {
        //stab
        //for defi operator only
    }

    /** 
     * @notice Distributes reward tokens. May be called by bot, if there was no deposits/withdrawals
     */
    function distributeRewards() public {
        //stab
        //for defi operator only
    }

// inherited from IVaultSavings
    function quickWithdraw(address _vaultProtocol, address token, uint256 dnAmount, uint256 maxNAmount)
    public //operationAllowed(IAccessModule.Operation.Withdraw)
    returns(uint256)
    {
        //stab

        //calls VaultProtocol.quickWithdraw(), so the caller pays for the gas
        
        return 0;
    }

    function claimWithdraw(address _vaultProtocol, address token, uint256 dnAmount, uint256 maxNAmount)
    public //operationAllowed(IAccessModule.Operation.Withdraw)
    returns(uint256)
    {
        //stab

        //The caller claims funds from the VaultProtocol after the fullfilled request.
        //Tokens are simply transferred from the VaultProtocol
        
        return 0;
    }

    function handleWithdrawRequests(address _vaultProtocol) public onlyDefiOperator {
        //stab
        //operator checks all the requests to the VaultProtocol and provides withdraw to the VaultProtocol
        //so the client can claim requested funds with VaultProtocol.claimWithdraw
        //Yeild is also calculated for the requestors

    }

    function handleDeposits(address _vaultProtocol) public onlyDefiOperator {
        //stab
        //operators deposits the funds through the VaultProtocol adapter to the target protocol (Curve)
        // and/or provides the steps defined by the yeild strategy (through IDefiStrategy methods)
    }

// inherited from RewardDistribution

    function poolTokenByProtocol(address _protocol) public view returns(address) {
        //stab
        return _protocol;
    }

    function protocolByPoolToken(address _poolToken) public view returns(address) {
        //stab
        return _poolToken;
    }

    function rewardTokensByProtocol(address _protocol) public view returns(address[] memory) {
        //stab
        address[] memory _rewardTokens = new address[](1);
        return _rewardTokens;
    }

    function registeredPoolTokens() public view returns(address[] memory poolTokens) {
        //stab
        poolTokens = new address[](1);
        return poolTokens;
    }

    function supportedRewardTokens() public view returns(address[] memory) {
        //stab
        address[] memory _supportedRewards = new address[](1);
        return _supportedRewards;
    }
}
