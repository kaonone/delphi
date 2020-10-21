pragma solidity ^0.5.12;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/SafeERC20.sol";

import "../../utils/CalcUtils.sol";

import "../../common/Module.sol";
import "../access/AccessChecker.sol";
import "./RewardDistributions.sol";
import "./SavingsCap.sol";
import "./VaultOperatorRole.sol";

import "../../interfaces/defi/IVaultProtocol.sol";
import "../../interfaces/savings/IVaultSavings.sol";

contract VaultSavingsModule is Module, IVaultSavings, AccessChecker, RewardDistributions, SavingsCap, VaultOperatorRole {
    uint256 constant MAX_UINT256 = uint256(-1);

    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    struct VaultInfo {
        VaultPoolToken poolToken;
        uint256 previousBalance;
    }

    address[] internal registeredVaults;
    mapping(address => VaultInfo) vaults;
    mapping(address => address) poolTokenToVault;

// ------
// Settings methods
// ------
    function initialize(address _pool) public initializer {
        Module.initialize(_pool);
        SavingsCap.initialize(_msgSender());
        VaultOperatorRole.initialize(_msgSender());
    }

    function registerVault(IVaultProtocol protocol, VaultPoolToken poolToken) public onlyOwner {
        require(!isVaultRegistered(address(protocol)), "Vault is already registered");

        registeredVaults.push(address(protocol));
        
        vaults[address(protocol)] = VaultInfo({
            poolToken: poolToken,
            previousBalance: protocol.normalizedBalance()
        });

        poolTokenToVault[address(poolToken)] = address(protocol);

        uint256 normalizedBalance = vaults[address(protocol)].previousBalance;
        if(normalizedBalance > 0) {
            uint256 ts = poolToken.totalSupply();
            if(ts < normalizedBalance) {
                poolToken.mint(_msgSender(), normalizedBalance.sub(ts));
            }
        }
        emit VaultRegistered(address(protocol), address(poolToken));
    }

// ------
// User interface
// ------
    //Deposits several tokens into single Vault
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

        require(!isProtocolCapExceeded(poolToken.totalSupply(), _protocol, _msgSender()), "Deposit exeeds protocols cap");

        uint256 cap;
        if (userCapEnabled) {
            cap = userCap(_protocol, _msgSender());
            require(cap >= nAmount, "Deposit exeeds user cap");
        }

        emit Deposit(_protocol, _msgSender(), nAmount, 0);
        return nAmount;
    }

    //Deposits into several vaults but one coin at time
    function deposit(address[] memory _protocols, address[] memory _tokens, uint256[] memory _dnAmounts) 
    public operationAllowed(IAccessModule.Operation.Deposit) 
    returns(uint256[] memory) 
    {
        require(_protocols.length == _tokens.length && _tokens.length == _dnAmounts.length, "Size of arrays does not match");
        uint256[] memory ptAmounts = new uint256[](_protocols.length);
        address[] memory tkns = new address[](1);
        uint256[] memory amnts = new uint256[](1);
        for (uint256 i=0; i < _protocols.length; i++) {
            tkns[0] = _tokens[i];
            amnts[0] = _dnAmounts[i];
            ptAmounts[i] = deposit(_protocols[i], tkns, amnts);
        }
        return ptAmounts;
    }

    function depositToProtocol(address _protocol, address[] memory _tokens, uint256[] memory _dnAmounts) internal {
        for (uint256 i=0; i < _tokens.length; i++) {
            address tkn = _tokens[i];
            IERC20(tkn).safeTransferFrom(_msgSender(), _protocol, _dnAmounts[i]);
            IVaultProtocol(_protocol).depositToVault(_msgSender(), tkn, _dnAmounts[i]);
            emit DepositToken(_protocol, tkn, _dnAmounts[i]);
        }
    }

    //Withdraw several tokens from a Vault in regular way or in quickWay
    function withdraw(address _vaultProtocol, address[] memory _tokens, uint256[] memory _amounts, bool isQuick)
    public operationAllowed(IAccessModule.Operation.Withdraw)
    returns(uint256)
    {
        require(isVaultRegistered(_vaultProtocol), "Vault is not registered");
        require(_tokens.length == _amounts.length, "Size of arrays does not match");

        uint256 actualAmount;
        uint256 normAmount;
        for (uint256 i = 0; i < _amounts.length; i++) {
            normAmount = CalcUtils.normalizeAmount(_tokens[i], _amounts[i]);
            actualAmount = actualAmount.add(normAmount);

            emit WithdrawToken(address(_vaultProtocol), _tokens[i], normAmount);
        }

        if (isQuick) {
            address _strategy = IVaultProtocol(_vaultProtocol).quickWithdrawStrategy();
            distributeYieldInternal(_vaultProtocol, _strategy);
            IVaultProtocol(_vaultProtocol).quickWithdraw(_msgSender(), _tokens, _amounts);
            updateProtocolBalance(_vaultProtocol, _strategy);
        }
        else {
            if (_tokens.length == 1) {
                IVaultProtocol(_vaultProtocol).withdrawFromVault(_msgSender(), _tokens[0], _amounts[0]);
            }
            else {
                IVaultProtocol(_vaultProtocol).withdrawFromVault(_msgSender(), _tokens, _amounts);
            }
        }

        VaultPoolToken poolToken = VaultPoolToken(vaults[_vaultProtocol].poolToken);
        poolToken.burnFrom(_msgSender(), actualAmount);
        emit Withdraw(_vaultProtocol, _msgSender(), actualAmount, 0);

        return actualAmount;
    }

    //Withdraw several tokens from several Vaults
    function withdrawAll(address[] memory _vaults, address[] memory _tokens, uint256[] memory _dnAmounts)
    public operationAllowed(IAccessModule.Operation.Withdraw)
    returns(uint256[] memory) 
    {
        require(_tokens.length == _dnAmounts.length, "Size of arrays does not match");

        uint256[] memory ptAmounts = new uint256[](_vaults.length);
        uint256 curInd;
        uint256 lim;
        uint256 nTokens;
        for (uint256 i=0; i < _vaults.length; i++) {
            nTokens = IVaultProtocol(_vaults[i]).supportedTokensCount();
            lim = curInd + nTokens;
            
            require(_tokens.length >= lim, "Incorrect tokens length");
            
            address[] memory tkns = new address[](nTokens);
            uint256[] memory amnts = new uint256[](nTokens);

            for (uint256 j = curInd; j < lim; j++) {
                tkns[j-curInd] = _tokens[j];
                amnts[j-curInd] = _dnAmounts[j];
            }

            ptAmounts[i] = withdraw(_vaults[i], tkns, amnts, false);

            curInd += nTokens;
        }
        return ptAmounts;
    }

    function claimAllRequested(address _vaultProtocol) public
    {
        require(isVaultRegistered(_vaultProtocol), "Vault is not registered");
        IVaultProtocol(_vaultProtocol).claimRequested(_msgSender());
    }

// ------
// Operator interface
// ------
    function handleOperatorActions(address _vaultProtocol, address _strategy, address _token) public onlyVaultOperator {
        uint256 totalDeposit;
        uint256 totalWithdraw;

        VaultPoolToken poolToken = VaultPoolToken(vaults[_vaultProtocol].poolToken);

        uint256 nBalanceBefore = distributeYieldInternal(_vaultProtocol, _strategy);
        if (_token == address(0)) {
            (totalDeposit, totalWithdraw) = IVaultProtocol(_vaultProtocol).operatorAction(_strategy);
        }
        else {
            (totalDeposit, totalWithdraw) = IVaultProtocol(_vaultProtocol).operatorActionOneCoin(_strategy, _token);
        }
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

    function clearProtocolStorage(address _vaultProtocol) public onlyVaultOperator {
        IVaultProtocol(_vaultProtocol).clearOnHoldDeposits();
        IVaultProtocol(_vaultProtocol).clearWithdrawRequests();
    }

    function distributeYield(address _vaultProtocol) public {
        address[] memory availableStrategies = IVaultProtocol(_vaultProtocol).registeredStrategies();
        for (uint256 i = 0; i < availableStrategies.length; i++) {
            distributeYieldInternal(_vaultProtocol, availableStrategies[i]);
        }
    }

    function setVaultRemainder(address _vaultProtocol, uint256 _amount, uint256 _index) public onlyVaultOperator {
        IVaultProtocol(_vaultProtocol).setRemainder(_amount, _index);
    }

// ------
// Getters and checkers
// ------
    function poolTokenByProtocol(address _vaultProtocol) public view returns(address) {
        return address(vaults[_vaultProtocol].poolToken);
    }

    function protocolByPoolToken(address _poolToken) public view returns(address) {
        return poolTokenToVault[_poolToken];
    }

    function userCap(address _protocol, address user) public view returns(uint256) {
        uint256 balance = vaults[_protocol].poolToken.balanceOf(user);
        return getUserCapLeft(_protocol, balance);
    }

    function isVaultRegistered(address _protocol) public view returns(bool) {
        for (uint256 i = 0; i < registeredVaults.length; i++){
            if (registeredVaults[i] == _protocol) return true;
        }
        return false;
    }

    function supportedVaults() public view returns(address[] memory) {
        return registeredVaults;
    }

// ------
// Yield distribution internal helpers
// ------
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

    function updateProtocolBalance(address _protocol, address _strategy) internal returns(uint256){
        uint256 currentBalance = IVaultProtocol(_protocol).normalizedBalance(_strategy);
        vaults[_protocol].previousBalance = currentBalance;
        return currentBalance;
    }
}
