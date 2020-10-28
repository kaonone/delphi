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

contract VaultProtocol is Module, IVaultProtocol, DefiOperatorRole {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address[] internal strategies;
    address[] internal registeredVaultTokens;

    //deposits waiting for the defi operator's actions
    mapping(address => uint256[]) internal balancesOnHold;
    address[] internal usersDeposited; //for operator's conveniency
    uint256[] lastProcessedDeposits;

    //Withdraw requests waiting for the defi operator's actions
    mapping(address => uint256[]) internal balancesRequested;
    address[] internal usersRequested; //for operator's conveniency
    uint256[] lastProcessedRequests;

    mapping(address => uint256[]) internal balancesToClaim;
    uint256[] internal claimableTokens;

    address public quickStrategy;

    //Quick disable of direct withdraw
    bool internal availableEnabled;
    uint256[] internal remainders;

// ------
// Settings methods
// ------
    function initialize(address _pool, address[] memory tokens) public initializer {
        Module.initialize(_pool);
        DefiOperatorRole.initialize(_msgSender());

        registeredVaultTokens = new address[](tokens.length);
        claimableTokens = new uint256[](tokens.length);
        lastProcessedRequests = new uint256[](tokens.length);
        lastProcessedDeposits = new uint256[](tokens.length);

        remainders = new uint256[](tokens.length);

        for (uint256 i = 0; i < tokens.length; i++) {
            registeredVaultTokens[i] = tokens[i];
        }

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
        remainders[_index] = _amount;
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

        uint256 ind;
        bool hasToken;

        (hasToken, ind) = tokenInfo(_token, registeredVaultTokens);
        require(hasToken, "Token is not registered in the vault");

        //At this point token is transfered from VaultSavings

        if (balancesOnHold[_user].length == 0) {
            balancesOnHold[_user] = new uint256[](supportedTokensCount());
        }
        usersDeposited.push(_user);
        balancesOnHold[_user][ind] = balancesOnHold[_user][ind].add(_amount);

        IVaultSavings vaultSavings = IVaultSavings(getModuleAddress(MODULE_VAULT));
        address vaultPoolToken = vaultSavings.poolTokenByProtocol(address(this));
        IOperableToken(vaultPoolToken).increaseOnHoldValue(_user, CalcUtils.normalizeAmount(_token, _amount));

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

        uint256 indReg;
        bool hasToken;

        (hasToken, indReg) = tokenInfo(_token, registeredVaultTokens);
        require(hasToken, "Token is not registered in the vault");


        if (availableEnabled && (IERC20(_token).balanceOf(address(this)).sub(claimableTokens[indReg]) >= _amount.add(remainders[indReg]))) {
            decreaseOnHoldDeposit(_user, _token, _amount);

            IERC20(_token).safeTransfer(_user, _amount);

            emit WithdrawFromVault(_user, _token, _amount);
        }
        else {
            if (balancesRequested[_user].length == 0) {
                balancesRequested[_user] = new uint256[](supportedTokensCount());
            }
            usersRequested.push(_user);
            balancesRequested[_user][indReg] = balancesRequested[_user][indReg].add(_amount);

            decreaseOnHoldDeposit(_user, _token, _amount);

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
        require(_tokens.length == 1 || _amounts.length == supportedTokensCount(), "Incorrect number of tokens");

        if (_tokens.length == 1) {
            IDefiStrategy(quickStrategy).withdraw(_user, _tokens[0], _amounts[0]);
        }
        else {
            //require correct order
            IDefiStrategy(quickStrategy).withdraw(_user, _amounts);
        }
    }

    function claimRequested(address _user) public {
        if (balancesToClaim[_user].length == 0) return;
        for (uint256 i = 0; i < balancesToClaim[_user].length; i++) {
            address token = registeredVaultTokens[i];
            uint256 amount = balancesToClaim[_user][i];

            if (amount > 0) {
                IERC20(token).safeTransfer(_user, amount);
                claimableTokens[i] = claimableTokens[i].sub(amount);
                emit Claimed(address(this), _user, token, amount);
            }
        }
        delete balancesToClaim[_user];
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
        uint256[] memory withdrawAmounts = new uint256[](registeredVaultTokens.length);
        uint256 lastProcessedRequest = minProcessed(lastProcessedRequests);
        uint256 amountToWithdraw;

        for (uint256 i = lastProcessedRequest; i < usersRequested.length; i++) {
            _user = usersRequested[i];
            for (uint256 j = 0; j < balancesRequested[_user].length; j++) {
                amountToWithdraw = requestToClaim(_user, j);
                if (amountToWithdraw > 0) {
                    withdrawAmounts[j] = withdrawAmounts[j].add(amountToWithdraw);
                }
            }
        }
        if (usersRequested.length > lastProcessedRequest) {
            setProcessed(lastProcessedRequests, usersRequested.length);
        }
        //Withdraw requests records can be cleared now

        uint256[] memory depositAmounts = new uint256[](registeredVaultTokens.length);
        uint256 totalDeposit = 0;
        uint256 totalWithdraw = 0;
        for (uint256 i = 0; i < registeredVaultTokens.length; i++) {
            depositAmounts[i] = IERC20(registeredVaultTokens[i]).balanceOf(address(this)).sub(claimableTokens[i]);
            depositAmounts[i] = handleRemainders(depositAmounts[i], i);

            IERC20(registeredVaultTokens[i]).safeApprove(address(_strategy), depositAmounts[i]);

            totalDeposit = totalDeposit.add(CalcUtils.normalizeAmount(registeredVaultTokens[i], depositAmounts[i]));

            totalWithdraw = totalWithdraw.add(CalcUtils.normalizeAmount(registeredVaultTokens[i], withdrawAmounts[i]));
        }
        //one of two things should happen for the same token: deposit or withdraw
        //simultaneous deposit and withdraw are applied to different tokens
        if (totalDeposit > 0) {
            IDefiStrategy(_strategy).handleDeposit(registeredVaultTokens, depositAmounts);
            emit DepositByOperator(totalDeposit);
        }

        if (totalWithdraw > 0) {
            IDefiStrategy(_strategy).withdraw(address(this), withdrawAmounts);
            emit WithdrawByOperator(totalWithdraw);
            //All just withdraw funds mark as claimable
            for (uint256 i = 0; i < claimableTokens.length; i++) {
                claimableTokens[i] = claimableTokens[i].add(withdrawAmounts[i]);
            }
        }
        emit WithdrawRequestsResolved(totalDeposit, totalWithdraw);
        return (totalDeposit, totalWithdraw);
    }

    function operatorActionOneCoin(address _strategy, address _token) public onlyDefiOperator returns(uint256, uint256) {
        require(isStrategyRegistered(_strategy), "Strategy is not registered");

        bool isReg;
        uint256 ind;

        (isReg, ind) = tokenInfo(_token, registeredVaultTokens);
        require(isReg, "Token is not supported");

        processOnHoldDeposit(ind);
        //On-hold records can be cleared now

        address _user;
        uint256 totalWithdraw = 0;
        uint256 amountToWithdraw;
        for (uint256 i = lastProcessedRequests[ind]; i < usersRequested.length; i++) {
            _user = usersRequested[i];

            amountToWithdraw = requestToClaim(_user, ind);
            
            if (amountToWithdraw > 0) {
                totalWithdraw = totalWithdraw.add(amountToWithdraw);
            }
        }
        lastProcessedRequests[ind] = usersRequested.length;
        //Withdraw requests records can be cleared now

        uint256 totalDeposit = IERC20(_token).balanceOf(address(this)).sub(claimableTokens[ind]);
        totalDeposit = handleRemainders(totalDeposit, ind);

        IERC20(_token).safeApprove(address(_strategy), totalDeposit);

        //one of two things should happen for the same token: deposit or withdraw
        //simultaneous deposit and withdraw are applied to different tokens
        if (totalDeposit > 0) {
            IDefiStrategy(_strategy).handleDeposit(_token, totalDeposit);
            emit DepositByOperator(totalDeposit);
        }

        if (totalWithdraw > 0) {
            IDefiStrategy(_strategy).withdraw(address(this), _token, totalWithdraw);
            emit WithdrawByOperator(totalWithdraw);
            //All just withdraw funds mark as claimable
            claimableTokens[ind] = claimableTokens[ind].add(totalWithdraw);
        }
        emit WithdrawRequestsResolved(totalDeposit, totalWithdraw);
        return (CalcUtils.normalizeAmount(registeredVaultTokens[ind], totalDeposit),
                CalcUtils.normalizeAmount(registeredVaultTokens[ind], totalWithdraw));
    }

    function clearOnHoldDeposits() public onlyDefiOperator {
        require(minProcessed(lastProcessedDeposits) == usersDeposited.length, "There are unprocessed deposits");

        address _user;
        for (uint256 i = 0; i < usersDeposited.length; i++) {
            //We can delete the on-hold records now - the real balances will be deposited to protocol
            _user = usersDeposited[i];
            balancesOnHold[_user].length = 0;
        }
        delete usersDeposited;
        setProcessed(lastProcessedDeposits, 0);
        emit DepositsCleared(address(this));
    }

    function clearWithdrawRequests() public onlyDefiOperator {
        require(minProcessed(lastProcessedRequests) == usersRequested.length, "There are unprocessed requests");

        address _user;
        for (uint256 i = 0; i < usersRequested.length; i++) {
            _user = usersRequested[i];
            balancesRequested[_user].length = 0;
        }
        delete usersRequested;
        setProcessed(lastProcessedRequests, 0);
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
        uint256 summ;
        for (uint256 i=0; i < registeredVaultTokens.length; i++) {
            uint256 balance = IERC20(registeredVaultTokens[i]).balanceOf(address(this));
            summ = summ.add(CalcUtils.normalizeAmount(registeredVaultTokens[i], balance));
        }
        return summ;
    }

    function totalClaimableAmount(address _token) public view returns (uint256) {
        uint256 indReg = tokenRegisteredInd(_token);

        return claimableTokens[indReg];
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
    function quickWithdrawStrategy() public view returns(address) {
        return quickStrategy;
    }

    function getRemainder(uint256 _index) public  view returns(uint256) {
        require(_index < supportedTokensCount());
        return remainders[_index];
    }

    function supportedTokens() public view returns(address[] memory) {
        return registeredVaultTokens;
    }

    function supportedTokensCount() public view returns(uint256) {
        return registeredVaultTokens.length;
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
        bool isReg = false;
        for (uint i = 0; i < registeredVaultTokens.length; i++) {
            if (registeredVaultTokens[i] == _token) {
                isReg = true;
                break;
            }
        }
        return isReg;
    }

    function tokenRegisteredInd(address _token) public view returns (uint256) {
        uint256 ind = 0;
        for (uint i = 0; i < registeredVaultTokens.length; i++) {
            if (registeredVaultTokens[i] == _token) {
                ind = i;
                break;
            }
        }
        return ind;
    }

// ------
// Internal helpers
// ------
    function tokenAmount(mapping(address => uint256[]) storage _amounts, address _user, address _token) internal view returns(uint256) {
        uint256 ind = tokenRegisteredInd(_token);
        if (_amounts[_user].length == 0)
            return 0;
        else
            return _amounts[_user][ind];
    }

    function tokenInfo(address _token, address[] storage tokensArr) internal view returns (bool, uint256) {
        uint256 ind = 0;
        bool isToken = false;
        for (uint i = 0; i < tokensArr.length; i++) {
            if (tokensArr[i] == _token) {
                ind = i;
                isToken = true;
                break;
            }
        }
        return (isToken, ind);
    }

    function processOnHoldDeposit() internal {
        IVaultSavings vaultSavings = IVaultSavings(getModuleAddress(MODULE_VAULT));
        IOperableToken vaultPoolToken = IOperableToken(vaultSavings.poolTokenByProtocol(address(this)));

        address _user;
        uint256 lastProcessedDeposit = minProcessed(lastProcessedDeposits);
        for (uint256 i = lastProcessedDeposit; i < usersDeposited.length; i++) {
            //We can delete the on-hold records now - the real balances will be deposited to protocol
            _user = usersDeposited[i];
            for (uint256 j = 0; j < balancesOnHold[_user].length; j++) {
                if (balancesOnHold[_user][j] > 0) {
                    vaultPoolToken.decreaseOnHoldValue(_user, CalcUtils.normalizeAmount(registeredVaultTokens[j], balancesOnHold[_user][j]));
                    balancesOnHold[_user][j] = 0;
                }
            }
        }
        if (usersDeposited.length > lastProcessedDeposit) {
            setProcessed(lastProcessedDeposits, usersDeposited.length);
        }
    }

    function processOnHoldDeposit(uint256 coinNum) internal {
        require(coinNum < supportedTokensCount(), "Incorrect coin index");
        IVaultSavings vaultSavings = IVaultSavings(getModuleAddress(MODULE_VAULT));
        IOperableToken vaultPoolToken = IOperableToken(vaultSavings.poolTokenByProtocol(address(this)));

        address _user;
        for (uint256 i = lastProcessedDeposits[coinNum]; i < usersDeposited.length; i++) {
            //We can delete the on-hold records now - the real balances will be deposited to protocol
            _user = usersDeposited[i];
            if (balancesOnHold[_user][coinNum] > 0) {
                vaultPoolToken.decreaseOnHoldValue(_user, CalcUtils.normalizeAmount(registeredVaultTokens[coinNum], balancesOnHold[_user][coinNum]));
                balancesOnHold[_user][coinNum] = 0;
            }
        }
        if (usersDeposited.length > lastProcessedDeposits[coinNum])
            lastProcessedDeposits[coinNum] = usersDeposited.length;
    }

    function decreaseOnHoldDeposit(address _user, address _token, uint256 _amount) internal {
        uint256 ind = tokenRegisteredInd(_token);
        if (balancesOnHold[_user].length == 0 || balancesOnHold[_user][ind] == 0) return;

        IVaultSavings vaultSavings = IVaultSavings(getModuleAddress(MODULE_VAULT));
        IOperableToken vaultPoolToken = IOperableToken(vaultSavings.poolTokenByProtocol(address(this)));

        if (balancesOnHold[_user][ind] > _amount) {
            vaultPoolToken.decreaseOnHoldValue(_user, CalcUtils.normalizeAmount(registeredVaultTokens[ind], _amount));
            balancesOnHold[_user][ind] = balancesOnHold[_user][ind].sub(_amount);
        }
        else {
            vaultPoolToken.decreaseOnHoldValue(_user, CalcUtils.normalizeAmount(registeredVaultTokens[ind], balancesOnHold[_user][ind]));
            balancesOnHold[_user][ind] = 0;
        }
    }

    function addClaim(address _user, address _token, uint256 _amount) internal {
        uint256 ind = tokenRegisteredInd(_token);

        if (balancesToClaim[_user].length == 0) {
            balancesToClaim[_user] = new uint256[](supportedTokensCount());
        }
        balancesToClaim[_user][ind] = balancesToClaim[_user][ind].add(_amount);
    }

    function requestToClaim(address _user, uint256 _ind) internal returns(uint256) {
        uint256 amount = balancesRequested[_user][_ind];
        address token = registeredVaultTokens[_ind];
        uint256 amountToWithdraw;
        uint256 tokenBalance;
        if (amount > 0) {
            addClaim(_user, token, amount);
                    
            //move tokens to claim if there is a liquidity
            tokenBalance = IERC20(token).balanceOf(address(this)).sub(claimableTokens[_ind]);
            tokenBalance = handleRemainders(tokenBalance, _ind);

            if (tokenBalance >= amount) {
                claimableTokens[_ind] = claimableTokens[_ind].add(amount);
            }
            else {
                if (tokenBalance > 0) {
                    claimableTokens[_ind] = claimableTokens[_ind].add(tokenBalance);
                    amountToWithdraw = amount.sub(tokenBalance);
                }
                else {
                    amountToWithdraw = amount;
                }
            }

            balancesRequested[_user][_ind] = 0;
        }
        return amountToWithdraw;
    }

    function setProcessed(uint256[] storage processedValues, uint256 value) internal {
        for (uint256 i = 0; i < processedValues.length; i++) {
            processedValues[i] = value;
        }
    }

    function minProcessed(uint256[] storage processedValues) internal view returns(uint256) {
        uint256 min = processedValues[0];
        for (uint256 i = 1; i < processedValues.length; i++) {
            if (processedValues[i] < min) {
                min = processedValues[i];
            }
        }
        return min;
    }

    function handleRemainders(uint256 _amount, uint256 _ind) internal view returns(uint256) {
        if (_amount >= remainders[_ind]) {
            return _amount.sub(remainders[_ind]);
        }
        else {
            return 0;
        }
    }
}