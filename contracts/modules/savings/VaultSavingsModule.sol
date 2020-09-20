pragma solidity ^0.5.12;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/SafeERC20.sol";
import "../../interfaces/defi/IVaultProtocol.sol";
import "../../interfaces/savings/IVaultSavings.sol";
import "./SavingsModule.sol";
import "../defi/DefiOperatorRole.sol";

contract VaultSavingsModule is SavingsModule, IVaultSavings, DefiOperatorRole {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    function initialize(address _pool) public initializer {
        SavingsModule.initialize(_pool);
        DefiOperatorRole.initialize(_msgSender());
    }


// Inherited from ISavingsModule
 /**
     * @notice Deposit tokens to a protocol
     * @param _protocol Protocol to deposit tokens
     * @param _tokens Array of tokens to deposit
     * @param _dnAmounts Array of amounts (denormalized to token decimals)
     */
    function deposit(address _protocol, address[] memory _tokens, uint256[] memory _dnAmounts)
    public operationAllowed(IAccessModule.Operation.Deposit)
    returns(uint256) 
    {
        //distributeRewardIfRequired(_protocol);

        uint256 nAmount;
        for (uint256 i=0; i < _tokens.length; i++) {
            nAmount = nAmount.add(normalizeTokenAmount(_tokens[i], _dnAmounts[i]));
        }

        depositToProtocol(_protocol, _tokens, _dnAmounts);

        PoolToken poolToken = PoolToken(protocols[_protocol].poolToken);
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
        uint256 nAmount = normalizeTokenAmount(token, dnAmount);

        IVaultProtocol(_protocol).withdrawFromVault(_msgSender(), token, dnAmount);

        PoolToken poolToken = PoolToken(protocols[_protocol].poolToken);
        poolToken.burnFrom(_msgSender(), dnAmount);
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

    function claimWithdraw(address _vaultProtocol, address _token, uint256 _amount)
    public //operationAllowed(IAccessModule.Operation.Withdraw)
    returns(uint256)
    {
        //stab

        //The caller claims funds from the VaultProtocol after the fullfilled request.
        //Tokens are simply transferred from the VaultProtocol
        
        return 0;
    }

    function handleWithdrawRequests(address _vaultProtocol, address token, uint256 dnAmount, uint256 maxNAmount) public onlyDefiOperator {
        uint256 nAmount = normalizeTokenAmount(token, dnAmount);

        uint256 nBalanceBefore = distributeYieldInternal(_vaultProtocol);
        IVaultProtocol(_vaultProtocol).withdrawOperator();
        uint256 nBalanceAfter = updateProtocolBalance(_vaultProtocol);

        uint256 yield;
        uint256 actualAmount;
        uint256 fee;
        if(nBalanceAfter.add(nAmount) > nBalanceBefore) {
            yield = nBalanceAfter.add(nAmount).sub(nBalanceBefore);
            actualAmount = nAmount;
        }else{
            actualAmount = nBalanceBefore.sub(nBalanceAfter);
            if (actualAmount > nAmount) fee = actualAmount-nAmount;
        }

        require(maxNAmount == 0 || actualAmount <= maxNAmount, "SavingsModule: provided maxNAmount is too low");

        PoolToken poolToken = PoolToken(protocols[_vaultProtocol].poolToken);
        poolToken.burnFrom(_msgSender(), actualAmount);
        emit WithdrawToken(_vaultProtocol, token, dnAmount);
        emit Withdraw(_vaultProtocol, _msgSender(), actualAmount, fee);


        if (yield > 0) {
            //Additional Yield received from protocol (because of lottery, or something)
            createYieldDistribution(poolToken, yield);
        }

//        return actualAmount;
    }
}
