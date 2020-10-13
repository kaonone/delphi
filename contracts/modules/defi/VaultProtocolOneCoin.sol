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

    //Quick disable of direct withdraw
    bool internal availableEnabled;

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
    }

    function depositToVault(address _user, address _token, uint256 _amount) public onlyDefiOperator {
        require(_user != address(0), "Incorrect user address");
        require(_token != address(0), "Incorrect token address");
        require(_amount > 0, "No tokens to be deposited");

        require(_token == registeredVaultToken, "Token is not registered in the vault");

        IERC20(_token).transferFrom(_user, address(this), _amount);

        usersDeposited.push(_user);
        balancesOnHold[_user] = balancesOnHold[_user].add(_amount);

        IVaultSavings vaultSavings = IVaultSavings(getModuleAddress(MODULE_VAULT));
        address vaultPoolToken = vaultSavings.poolTokenByProtocol(address(this));
        IOperableToken(vaultPoolToken).increaseOnHoldValue(_user, _amount);

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
        require(_amount > 0, "No tokens to be withdrawn");

        require(_token == registeredVaultToken, "Token is not registered in the vault");


        if (availableEnabled && IERC20(_token).balanceOf(address(this)).sub(claimableTokens) >= _amount) {
            IERC20(_token).transfer(_user, _amount);

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

    function operatorAction(address _strategy) public onlyDefiOperator returns(uint256, uint256) {
        require(isStrategyRegistered(_strategy), "Strategy is not registered");
        //Yield distribution step based on actual deposits (excluding on-hold ones)
        // should be performed from the SavingsModule before other operator's actions

        processOnHoldDeposit();
        //On-hold records can be cleared now

        address _user;
        uint256 totalWithdraw = 0;
        uint256 tokenBalance;
        for (uint256 i = lastProcessedRequest; i < usersRequested.length; i++) {
            _user = usersRequested[i];
            uint256 amount = balancesRequested[_user];
            if (amount > 0) {
                addClaim(_user, registeredVaultToken, amount);
                    
                //move tokens to claim if there is a liquidity
                tokenBalance = IERC20(registeredVaultToken).balanceOf(address(this)).sub(claimableTokens);
                if (tokenBalance >= amount) {
                    claimableTokens = claimableTokens.add(amount);
                }
                else {
                    if (tokenBalance > 0) {
                        claimableTokens = claimableTokens.add(tokenBalance);
                        totalWithdraw = totalWithdraw.add(amount.sub(tokenBalance));
                    }
                    else {
                        totalWithdraw = totalWithdraw.add(amount);
                    }
                }
                balancesRequested[_user] = 0;
            }
        }
        lastProcessedRequest = usersRequested.length;
        //Withdraw requests records can be cleared now

        uint256 totalDeposit = IERC20(registeredVaultToken).balanceOf(address(this)).sub(claimableTokens);
        IERC20(registeredVaultToken).approve(address(_strategy), totalDeposit);

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
        return (totalDeposit, totalWithdraw);
    }

    function operatorActionOneCoin(address _strategy, address _token) public onlyDefiOperator returns(uint256, uint256) {
        require(isTokenRegistered(_token), "Token is not registered");
        return operatorAction(_strategy);
    }

    function clearOnHoldDeposits() public onlyDefiOperator {
        delete usersDeposited;
        lastProcessedDeposit = 0;
    }

    function clearWithdrawRequests() public onlyDefiOperator {
        delete usersRequested;
        lastProcessedRequest = 0;
    }

    function quickWithdraw(address _user, uint256 _amount) public onlyDefiOperator {
        //stab
        //available for any how pays for all the gas and is allowed to withdraw
        //should be overloaded in the protocol adapter itself
    }

    function claimRequested(address _user) public {
        if (balancesToClaim[_user] == 0) return;

        IERC20(registeredVaultToken).transfer(_user, balancesToClaim[_user]);
        claimableTokens = claimableTokens.sub(balancesToClaim[_user]);

        balancesToClaim[_user] = 0;
    }

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

    function setAvailableEnabled(bool value) public onlyDefiOperator {
        availableEnabled = value;
    }

    function normalizedVaultBalance() public view returns(uint256) {
        uint256 balance = IERC20(registeredVaultToken).balanceOf(address(this));

        return CalcUtils.normalizeAmount(registeredVaultToken, balance);
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
            
            vaultPoolToken.decreaseOnHoldValue(_user, balancesOnHold[_user]);
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
            vaultPoolToken.decreaseOnHoldValue(_user, balancesOnHold[_user]);
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
}