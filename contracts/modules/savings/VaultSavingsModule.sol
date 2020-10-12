pragma solidity ^0.5.12;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/SafeERC20.sol";

import "../../utils/CalcUtils.sol";

import "../../common/Module.sol";
import "../access/AccessChecker.sol";
import "./RewardDistributions.sol";
import "./SavingsCap.sol";
import "../defi/DefiOperatorRole.sol";

import "../../interfaces/defi/IVaultProtocol.sol";
import "../../interfaces/savings/IVaultSavings.sol";

contract VaultSavingsModule is Module, IVaultSavings, AccessChecker, RewardDistributions, SavingsCap, DefiOperatorRole {
    uint256 constant MAX_UINT256 = uint256(-1);
    uint256 public constant DISTRIBUTION_AGGREGATION_PERIOD = 24*60*60;

    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    struct VaultInfo {
        VaultPoolToken poolToken;
        uint256 previousBalance;
        uint256 lastRewardDistribution;
        uint256 withdrawAllSlippage;         //Allowed slippage for withdrawAll function in wei
    }

    IVaultProtocol[] registeredVaults;
    mapping(address => VaultInfo) vaults;
    mapping(address => address) poolTokenToVault;

    function initialize(address _pool) public initializer {
        Module.initialize(_pool);
        SavingsCap.initialize(_msgSender());
        DefiOperatorRole.initialize(_msgSender());
    }

    function registerVault(IVaultProtocol protocol, VaultPoolToken poolToken) public onlyOwner {
        uint256 i;
        for (i = 0; i < registeredVaults.length; i++){
            if (address(registeredVaults[i]) == address(protocol)) revert("VaultSavingsModule: vault already registered");
        }
        registeredVaults.push(protocol);
        
        vaults[address(protocol)] = VaultInfo({
            poolToken: poolToken,
            previousBalance: protocol.normalizedBalance(),
            lastRewardDistribution: 0,
            withdrawAllSlippage:0
        });

        poolTokenToVault[address(poolToken)] = address(protocol);

 //       address[] memory supportedTokens = protocol.supportedTokens();
 //       for (i = 0; i < supportedTokens.length; i++) {
 //           address tkn = supportedTokens[i];
 //           if (!isTokenRegistered(tkn)){
 //               registeredTokens.push(tkn);
 //               tokens[tkn].decimals = ERC20Detailed(tkn).decimals();
 //           }
 //       }
        uint256 normalizedBalance = vaults[address(protocol)].previousBalance;
        if(normalizedBalance > 0) {
            uint256 ts = poolToken.totalSupply();
            if(ts < normalizedBalance) {
                poolToken.mint(_msgSender(), normalizedBalance.sub(ts));
            }
        }
        emit VaultRegistered(address(protocol), address(poolToken));
    }

// Inherited from ISavingsModule
 /**
     * @notice Deposit from user to be transfered to the Vault
     * @param _protocol Protocol to deposit tokens
     * @param _tokens Array of tokens to deposit
     * @param _dnAmounts Array of amounts (denormalized to token decimals)
     */
    function deposit(address _protocol, address[] memory _tokens, uint256[] memory _dnAmounts)
    public operationAllowed(IAccessModule.Operation.Deposit)
    returns(uint256) 
    {
        require(isVaultRegistered(_protocol), "Vault is not registered");
        depositToProtocol(_protocol, _tokens, _dnAmounts);

        uint256 nAmount;
        for (uint256 i=0; i < _tokens.length; i++) {
            nAmount = nAmount.add(CalcUtils.normalizeAmount(_tokens[i], _dnAmounts[i]));
        }
        
        VaultPoolToken poolToken = VaultPoolToken(vaults[_protocol].poolToken);
        poolToken.mint(_msgSender(), nAmount);

        require(!isProtocolCapExceeded(poolToken.totalSupply(), _protocol, _msgSender()), "SavingsModule: deposit exeeds protocols cap");

        uint256 cap;
        if (userCapEnabled) {
            cap = userCap(_protocol, _msgSender());
            require(cap >= nAmount, "SavingsModule: deposit exeeds user cap");
        }

        emit Deposit(_protocol, _msgSender(), nAmount, 0);
        return nAmount;
    }

    function depositToProtocol(address _protocol, address[] memory _tokens, uint256[] memory _dnAmounts) internal {
        require(_tokens.length == _dnAmounts.length, "SavingsModule: count of tokens does not match count of amounts");

        for (uint256 i=0; i < _tokens.length; i++) {
            address tkn = _tokens[i];
            IVaultProtocol(_protocol).depositToVault(_msgSender(), tkn, _dnAmounts[i]);
            emit DepositToken(_protocol, tkn, _dnAmounts[i]);
        }
    }

    function deposit(address[] memory _protocols, address[] memory _tokens, uint256[] memory _dnAmounts) 
    public operationAllowed(IAccessModule.Operation.Deposit) 
    returns(uint256[] memory) 
    {
        require(_protocols.length == _tokens.length && _tokens.length == _dnAmounts.length, "VaultSavingsModule: size of arrays does not match");
        uint256[] memory ptAmounts = new uint256[](_protocols.length);
        for (uint256 i=0; i < _protocols.length; i++) {
            address[] memory tkns = new address[](1);
            tkns[0] = _tokens[i];
            uint256[] memory amnts = new uint256[](1);
            amnts[0] = _dnAmounts[i];
            ptAmounts[i] = deposit(_protocols[i], tkns, amnts);
        }
        return ptAmounts;
    }

    function depositAll(address[] memory _protocols, address[] memory _tokens, uint256[] memory _dnAmounts) 
    public operationAllowed(IAccessModule.Operation.Deposit) 
    returns(uint256[] memory) 
    {
        require(_tokens.length == _dnAmounts.length, "VaultSavingsModule: size of arrays does not match");

        uint256[] memory ptAmounts = new uint256[](_protocols.length);
        uint256 curInd;
        for (uint256 i=0; i < _protocols.length; i++) {
            uint256 nTokens = IVaultProtocol(_protocols[i]).supportedTokensCount();
            uint256 lim = curInd + nTokens;
            
            require(_tokens.length >= lim, "Incorrect tokens length");
            
            address[] memory tkns = new address[](nTokens);
            uint256[] memory amnts = new uint256[](nTokens);

            for (uint256 j = curInd; j < lim; j++) {
                tkns[j-curInd] = _tokens[j];
                amnts[j-curInd] = _dnAmounts[j];
            }

            ptAmounts[i] = deposit(_protocols[i], tkns, amnts);

            curInd += nTokens;
        }
        return ptAmounts;
    }

    function withdrawAll(address _protocol, uint256 nAmount)
    public operationAllowed(IAccessModule.Operation.Withdraw)
    returns(uint256) 
    {
        //stub

        return 0;
    }

    /**
     * Withdraw token from protocol
     * @param _protocol Protocol to withdraw from
     * @param token Token to withdraw
     * @param dnAmount Amount to withdraw (denormalized)
     * @param maxNAmount Max amount of PoolToken to burn
     * @return Amount of PoolToken burned from user
     */
    function withdraw(address _protocol, address token, uint256 dnAmount, uint256 maxNAmount)
    public operationAllowed(IAccessModule.Operation.Withdraw)
    returns(uint256){
        uint256 nAmount = CalcUtils.normalizeAmount(token, dnAmount);

        IVaultProtocol(_protocol).withdrawFromVault(_msgSender(), token, dnAmount);

        VaultPoolToken poolToken = VaultPoolToken(vaults[_protocol].poolToken);
        poolToken.burnFrom(_msgSender(), nAmount);
        emit WithdrawToken(_protocol, token, dnAmount);
        emit Withdraw(_protocol, _msgSender(), dnAmount, 0);

        return dnAmount;
    }




// inherited from IVaultSavings
    function quickWithdraw(address _vaultProtocol, address _token, uint256 _amount)
    public //operationAllowed(IAccessModule.Operation.Withdraw)
    returns(uint256)
    {
        //stab

        //calls VaultProtocol.quickWithdraw(), so the caller pays for the gas
        
        return 0;
    }

    function claimAllRequested(address _vaultProtocol) public
    {
        require(isVaultRegistered(_vaultProtocol), "Protocol is not registered");
        IVaultProtocol(_vaultProtocol).claimRequested(_msgSender());
    }

    function handleOperatorActions(address _vaultProtocol, address _strategy) public onlyDefiOperator {
        uint256 totalDeposit;
        uint256 totalWithdraw;

        VaultPoolToken poolToken = VaultPoolToken(vaults[_vaultProtocol].poolToken);

        uint256 nBalanceBefore = distributeYieldInternal(_vaultProtocol, _strategy);
        (totalDeposit, totalWithdraw) = IVaultProtocol(_vaultProtocol).operatorAction(_strategy);
        //Protocol records can be cleared now
        uint256 nBalanceAfter = updateProtocolBalance(_vaultProtocol, _strategy);

        uint256 yield;
        uint256 calcBalanceAfter = nBalanceBefore.add(totalDeposit).sub(totalWithdraw);
        if (nBalanceAfter > calcBalanceAfter) {
            yield = nBalanceAfter.sub(calcBalanceAfter);
        }

        if (yield > 0) {
            createYieldDistribution(poolToken, yield);
        }
    }

    function clearProtocolStorage(address _vaultProtocol) public onlyDefiOperator {
        IVaultProtocol(_vaultProtocol).clearOnHoldDeposits();
        IVaultProtocol(_vaultProtocol).clearWithdrawRequests();
    }

        /** 
     * @notice Distributes yield. May be called by bot, if there was no deposits/withdrawals
     */
    function distributeYield(address _vaultProtocol) public {
        address[] memory availableStrategies = IVaultProtocol(_vaultProtocol).registeredStrategies();
        for (uint256 i = 0; i < availableStrategies.length; i++) {
            distributeYieldInternal(_vaultProtocol, availableStrategies[i]);
        }
    }

/*    function distributeYieldInternal(address _vaultProtocol) internal returns(uint256){
        uint256 currentBalance = IVaultProtocol(_vaultProtocol).normalizedBalance();
        VaultInfo storage pi = vaults[_vaultProtocol];
        VaultPoolToken poolToken = VaultPoolToken(pi.poolToken);
        if(currentBalance > pi.previousBalance) {
            uint256 yield = currentBalance.sub(pi.previousBalance);
            pi.previousBalance = currentBalance;
            createYieldDistribution(poolToken, yield);
        }
        return currentBalance;
    }*/

    function distributeYieldInternal(address _vaultProtocol, address _strategy) internal returns(uint256){
        uint256 currentBalance = IVaultProtocol(_vaultProtocol).normalizedBalance(_strategy);
        VaultInfo storage pi = vaults[_vaultProtocol];
        VaultPoolToken poolToken = VaultPoolToken(pi.poolToken);
        if(currentBalance > pi.previousBalance) {
            uint256 yield = currentBalance.sub(pi.previousBalance);
            pi.previousBalance = currentBalance;
            createYieldDistribution(poolToken, yield);
        }
        return currentBalance;
    }

    function createYieldDistribution(VaultPoolToken poolToken, uint256 yield) internal {
        poolToken.distribute(yield);
        emit YieldDistribution(address(poolToken), yield);
    }

    function poolTokenByProtocol(address _vaultProtocol) public view returns(address) {
        return address(vaults[_vaultProtocol].poolToken);
    }

    function protocolByPoolToken(address _poolToken) public view returns(address) {
        return poolTokenToVault[_poolToken];
    }

    function registeredPoolTokens() public view returns(address[] memory poolTokens) {
        poolTokens = new address[](registeredVaults.length);
        for(uint256 i=0; i<poolTokens.length; i++){
            poolTokens[i] = address(vaults[address(registeredVaults[i])].poolToken);
        }
    }

    function isPoolToken(address token) internal view returns(bool) {
        for (uint256 i = 0; i < registeredVaults.length; i++){
            IVaultProtocol protocol = registeredVaults[i];
            if (address(vaults[address(protocol)].poolToken) == token) return true;
        }
        return false;
    }

    function supportedRewardTokens() public view returns(address[] memory rewardTokens) {
        return rewardTokens;
    }

    function userCap(address _protocol, address user) public view returns(uint256) {
        uint256 balance = vaults[_protocol].poolToken.balanceOf(user);
        return getUserCapLeft(_protocol, balance);
    }

    function isVaultRegistered(address _protocol) internal view returns(bool) {
        for (uint256 i = 0; i < registeredVaults.length; i++){
            if (address(registeredVaults[i]) == _protocol) return true;
        }
        return false;
    }

    function updateProtocolBalance(address _protocol, address _strategy) internal returns(uint256){
        uint256 currentBalance = IVaultProtocol(_protocol).normalizedBalance(_strategy);
        vaults[_protocol].previousBalance = currentBalance;
        return currentBalance;
    }
}
