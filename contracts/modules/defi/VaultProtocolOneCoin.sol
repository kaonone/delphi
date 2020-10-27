pragma solidity ^0.5.12;

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";

import "../../interfaces/defi/IVaultProtocol.sol";
import "../../interfaces/savings/IVaultSavings.sol";
import "../../interfaces/token/IOperableToken.sol";
import "../../interfaces/defi/IDefiStrategy.sol";
import "../../common/Module.sol";
import "./DefiOperatorRole.sol";

import "../../utils/CalcUtils.sol";

contract VaultProtocolOneCoin is Module, IVaultProtocol, DefiOperatorRole {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address[] internal strategies;
    address internal registeredVaultToken;

    //deposits waiting for the defi operator's actions
    mapping(address => uint256) internal balancesOnHold;
    address[] internal usersDeposited; //for operator's conveniency
    uint256 lastProcessedDeposit;

    //Withdraw requests waiting for the defi operator's actions
    mapping(address => uint256) internal balancesRequested;
    address[] internal usersRequested; //for operator's conveniency
    uint256 lastProcessedRequest;

    mapping(address => uint256) internal balancesToClaim;
    uint256 internal claimableTokens;

    address public quickStrategy;

    //Quick disable of direct withdraw
    bool internal availableEnabled;
    uint256 internal remainder;

// ------
// Settings methods
// ------
    function initialize(address _pool, address[] memory _tokens) public initializer {
        require(_tokens.length == 1, "Incorrect number of tokens");
        Module.initialize(_pool);
        DefiOperatorRole.initialize(_msgSender());

        registeredVaultToken = _tokens[0];

        availableEnabled = false;
    }

    function registerStrategy(address _strategy) public onlyDefiOperator {
        strategies.push(_strategy);
        IDefiStrategy(_strategy).setVault(address(this));

        emit StrategyRegistered(address(this), _strategy, IDefiStrategy(_strategy).getStrategyId());
    }

    function setQuickWithdrawStrategy(address _strategy) public onlyDefiOperator {
        require(isStrategyRegistered(_strategy), "Strategy is not registered");
        quickStrategy = _strategy;
    }

    function setRemainder(uint256 _amount, uint256 _index) public onlyDefiOperator {
        require(_index < supportedTokensCount());
        remainder = _amount;
    }
    
    function setAvailableEnabled(bool value) public onlyDefiOperator {
        availableEnabled = value;
    }

// ------
// Funds flow interface (for defiOperator)
// ------
    function depositToVault(address _user, address _token, uint256 _amount) public onlyDefiOperator {
        require(_user != address(0), "Incorrect user address");
        require(_token != address(0), "Incorrect token address");
        require(_amount > 0, "No tokens to be deposited");

        require(_token == registeredVaultToken, "Token is not registered in the vault");

        //At this point token is transfered from VaultSavings

        usersDeposited.push(_user);
        balancesOnHold[_user] = balancesOnHold[_user].add(_amount);

        IVaultSavings vaultSavings = IVaultSavings(getModuleAddress(MODULE_VAULT));
        address vaultPoolToken = vaultSavings.poolTokenByProtocol(address(this));
        IOperableToken(vaultPoolToken).increaseOnHoldValue(_user, CalcUtils.normalizeAmount(registeredVaultToken, _amount));

        emit DepositToVault(_user, _token, _amount);
    }

    function depositToVault(address _user, address[] memory  _tokens, uint256[] memory _amounts) public onlyDefiOperator {
        require(_tokens.length > 0, "No tokens to be deposited");
        require(_tokens.length == _amounts.length, "Incorrect amounts");

        for (uint256 i = 0; i < _tokens.length; i++) {
            depositToVault(_user, _tokens[i], _amounts[i]);
        }
    }

    function withdrawFromVault(address _user, address _token, uint256 _amount) public onlyDefiOperator {
        require(_user != address(0), "Incorrect user address");
        require(_token != address(0), "Incorrect token address");
        
        if (_amount == 0) return;
        
        require(_token == registeredVaultToken, "Token is not registered in the vault");


        if (availableEnabled && IERC20(_token).balanceOf(address(this)).sub(claimableTokens) >= _amount.add(remainder)) {
            IERC20(_token).safeTransfer(_user, _amount);

            emit WithdrawFromVault(_user, _token, _amount);

            decreaseOnHoldDeposit(_user, _token, _amount);
        }
        else {
            usersRequested.push(_user);
            balancesRequested[_user] = balancesRequested[_user].add(_amount);

            emit WithdrawRequestCreated(_user, _token, _amount);
        }
    }

    function withdrawFromVault(address _user, address[] memory  _tokens, uint256[] memory _amounts) public onlyDefiOperator {
        require(_tokens.length > 0, "No tokens to be withdrawn");
        require(_tokens.length == _amounts.length, "Incorrect amounts");

        for (uint256 i = 0; i < _tokens.length; i++) {
            withdrawFromVault(_user, _tokens[i], _amounts[i]);
        }
    }

    function quickWithdraw(address _user, address[] memory _tokens, uint256[] memory _amounts) public onlyDefiOperator {
        require(quickStrategy != address(0), "No strategy for quick withdraw");
        require(_amounts.length == supportedTokensCount(), "Incorrect number of tokens");
        require(_tokens[0] == registeredVaultToken, "Unsupported token");

        IDefiStrategy(quickStrategy).withdraw(_user, registeredVaultToken, _amounts[0]);
    }

    function claimRequested(address _user) public {
        if (balancesToClaim[_user] == 0) return;

        IERC20(registeredVaultToken).safeTransfer(_user, balancesToClaim[_user]);
        claimableTokens = claimableTokens.sub(balancesToClaim[_user]);

        emit Claimed(address(this), _user, registeredVaultToken, balancesToClaim[_user]);

        balancesToClaim[_user] = 0;
    }

// ------
// Operator interface
// ------
    function operatorAction(address _strategy) public onlyDefiOperator returns(uint256, uint256) {
        require(isStrategyRegistered(_strategy), "Strategy is not registered");
        //Yield distribution step based on actual deposits (excluding on-hold ones)
        // should be performed from the SavingsModule before other operator's actions

        processOnHoldDeposit();
        //On-hold records can be cleared now

        address _user;
        uint256 totalWithdraw = 0;
        uint256 amountToWithdraw;
        for (uint256 i = lastProcessedRequest; i < usersRequested.length; i++) {
            _user = usersRequested[i];
            amountToWithdraw = requestToClaim(_user);
            if (amountToWithdraw > 0) {
                totalWithdraw = totalWithdraw.add(amountToWithdraw);
            }
        }
        lastProcessedRequest = usersRequested.length;
        //Withdraw requests records can be cleared now

        uint256 totalDeposit = IERC20(registeredVaultToken).balanceOf(address(this)).sub(claimableTokens).sub(remainder);
        totalDeposit = handleRemainders(totalDeposit);

        IERC20(registeredVaultToken).safeApprove(address(_strategy), totalDeposit);

        //one of two things should happen for the same token: deposit or withdraw
        //simultaneous deposit and withdraw are applied to different tokens
        if (totalDeposit > 0) {
            IDefiStrategy(_strategy).handleDeposit(registeredVaultToken, totalDeposit);
            emit DepositByOperator(totalDeposit);
        }

        if (totalWithdraw > 0) {
            IDefiStrategy(_strategy).withdraw(address(this), registeredVaultToken, totalWithdraw);
            emit WithdrawByOperator(totalWithdraw);
            //All just withdraw funds mark as claimable
            claimableTokens = claimableTokens.add(totalWithdraw);
        }
        emit WithdrawRequestsResolved(totalDeposit, totalWithdraw);
        return (CalcUtils.normalizeAmount(registeredVaultToken, totalDeposit),
                CalcUtils.normalizeAmount(registeredVaultToken, totalWithdraw));
    }

    function operatorActionOneCoin(address _strategy, address _token) public onlyDefiOperator returns(uint256, uint256) {
        require(isTokenRegistered(_token), "Token is not registered");
        return operatorAction(_strategy);
    }

    function clearOnHoldDeposits() public onlyDefiOperator {
        require(lastProcessedDeposit == usersDeposited.length, "There are unprocessed deposits");
        delete usersDeposited;
        lastProcessedDeposit = 0;
        emit DepositsCleared(address(this));
    }

    function clearWithdrawRequests() public onlyDefiOperator {
        require(lastProcessedRequest == usersRequested.length, "There are unprocessed requests");
        delete usersRequested;
        lastProcessedRequest = 0;
        emit RequestsCleared(address(this));
    }

// ------
// Balances
// ------
    function normalizedBalance(address _strategy) public returns(uint256) {
        require(isStrategyRegistered(_strategy), "Strategy is not registered");
        return IDefiStrategy(_strategy).normalizedBalance();
    }

    function normalizedBalance() public returns(uint256) {
        uint256 total;
        for (uint256 i = 0; i < strategies.length; i++) {
            total = total.add(IDefiStrategy(strategies[i]).normalizedBalance());
        }
        return total;
    }

    function normalizedVaultBalance() public view returns(uint256) {
        uint256 balance = IERC20(registeredVaultToken).balanceOf(address(this));

        return CalcUtils.normalizeAmount(registeredVaultToken, balance);
    }

    function totalClaimableAmount(address _token) public view returns (uint256) {
        require(isTokenRegistered(_token), "Token is not registered");
        return claimableTokens;
    }

    function claimableAmount(address _user, address _token) public view returns (uint256) {
        return tokenAmount(balancesToClaim, _user, _token);
    }

    function amountOnHold(address _user, address _token) public view returns (uint256) {
        return tokenAmount(balancesOnHold, _user, _token);
    }

    function amountRequested(address _user, address _token) public view returns (uint256) {
        return tokenAmount(balancesRequested, _user, _token);
    }

// ------
// Getters and checkers
// ------
    function getRemainder(uint256 _index) public  view returns(uint256) {
        require(_index < supportedTokensCount());
        return remainder;
    }

    function quickWithdrawStrategy() public view returns(address) {
        return quickStrategy;
    }

    function supportedTokens() public view returns(address[] memory) {
        address[] memory _supportedTokens = new address[](1);
        _supportedTokens[0] = registeredVaultToken;
        return _supportedTokens;
    }

    function supportedTokensCount() public view returns(uint256) {
        return 1;
    }

    function isStrategyRegistered(address _strategy) public view returns(bool) {
        for (uint256 i = 0; i < strategies.length; i++) {
            if (strategies[i] == _strategy) {
                return true;
            }
        }
        return false;
    }

    function registeredStrategies() public view returns(address[] memory) {
        return strategies;
    }

    function isTokenRegistered(address _token) public view returns (bool) {
        return _token == registeredVaultToken;
    }

    function tokenRegisteredInd(address _token) public view returns (uint256) {
        require(isTokenRegistered(_token), "Token is not registered");
        return 0;
    }

// ------
// Internal helpers
// ------
    function tokenAmount(mapping(address => uint256) storage _amounts, address _user, address _token) internal view returns(uint256) {
        require(isTokenRegistered(_token), "Token is not registered");
        return _amounts[_user];
    }

    function processOnHoldDeposit() internal {
        IVaultSavings vaultSavings = IVaultSavings(getModuleAddress(MODULE_VAULT));
        IOperableToken vaultPoolToken = IOperableToken(vaultSavings.poolTokenByProtocol(address(this)));

        address _user;
        for (uint256 i = lastProcessedDeposit; i < usersDeposited.length; i++) {
            //We can delete the on-hold records now - the real balances will be deposited to protocol
            _user = usersDeposited[i];
            
            vaultPoolToken.decreaseOnHoldValue(_user, CalcUtils.normalizeAmount(registeredVaultToken, balancesOnHold[_user]));
            balancesOnHold[_user] = 0;
        }
        lastProcessedDeposit = usersDeposited.length;
    }

    function processOnHoldDeposit(uint256 coinNum) internal {
        require(coinNum < supportedTokensCount(), "Incorrect coin index");
        IVaultSavings vaultSavings = IVaultSavings(getModuleAddress(MODULE_VAULT));
        IOperableToken vaultPoolToken = IOperableToken(vaultSavings.poolTokenByProtocol(address(this)));

        address _user;
        for (uint256 i = lastProcessedDeposit; i < usersDeposited.length; i++) {
            //We can delete the on-hold records now - the real balances will be deposited to protocol
            _user = usersDeposited[i];
            vaultPoolToken.decreaseOnHoldValue(_user, CalcUtils.normalizeAmount(registeredVaultToken, balancesOnHold[_user]));
            balancesOnHold[_user] = 0;

        }
    }

    function decreaseOnHoldDeposit(address _user, address _token, uint256 _amount) internal {
        require(isTokenRegistered(_token), "Token is not registered");
        if (balancesOnHold[_user] > _amount) {
            balancesOnHold[_user] = balancesOnHold[_user].sub(_amount);
        }
        else {
            balancesOnHold[_user] = 0;
        }
    }

    function addClaim(address _user, address _token, uint256 _amount) internal {
        require(isTokenRegistered(_token), "Token is not registered");
        balancesToClaim[_user] = balancesToClaim[_user].add(_amount);
    }

    function requestToClaim(address _user) internal returns(uint256) {
        uint256 amount = balancesRequested[_user];
        uint256 amountToWithdraw;
        uint256 tokenBalance;
        if (amount > 0) {
            addClaim(_user, registeredVaultToken, amount);
                    
            //move tokens to claim if there is a liquidity
            tokenBalance = IERC20(registeredVaultToken).balanceOf(address(this)).sub(claimableTokens);
            tokenBalance = handleRemainders(tokenBalance);
            if (tokenBalance >= remainder) {
                tokenBalance = tokenBalance.sub(remainder);
            }
            else {
                tokenBalance = 0;
            }
            if (tokenBalance >= amount) {
                claimableTokens = claimableTokens.add(amount);
            }
            else {
                if (tokenBalance > 0) {
                    claimableTokens = claimableTokens.add(tokenBalance);
                    amountToWithdraw = amount.sub(tokenBalance);
                }
                else {
                    amountToWithdraw = amount;
                }
            }
            balancesRequested[_user] = 0;
        }
        return amountToWithdraw;
    }

    function handleRemainders(uint256 _amount) internal view returns(uint256) {
        if (_amount >= remainder) {
            return _amount.sub(remainder);
        }
        else {
            return 0;
        }
    }
}