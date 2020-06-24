pragma solidity ^0.5.12;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "../../interfaces/defi/IDefiModule.sol";
import "../../common/Module.sol";
import "./DefiOperatorRole.sol";

/**
* @dev DeFi integration module
* This module should be initialized only *AFTER*  module is available and address
* of DeFi source is set.
*/
contract DefiModuleBase is Module, DefiOperatorRole, IDefiModule {
    using SafeMath for uint256;

    uint256 public constant DISTRIBUTION_AGGREGATION_PERIOD = 24*60*60;


    //for one token
    struct Distribution {
        uint256 amount;         // Amount of Stablecoin being distributed during the event
        uint256 balance;        // Total amount of Stablecoin stored
        uint256 total;       // Total shares (stablecoins)
    }


    //for one token
    struct InvestmentBalance {
        uint256 balance;             // User's share of stablecoin
        uint256 availableBalance;       // Amount of DAI available to redeem
        uint256 nextDistribution;       // First distribution not yet processed
    }

    mapping(address => Distribution[]) distributions; //address - stablecoin

    uint256 public nextDistributionTimestamp;               //Timestamp when next distribuition should be fired
    mapping(address => mapping(address => InvestmentBalance)) public balances;  // Map account to first distribution not yet processed

    mapping (address => uint256) depositsSinceLastDistribution;                  // Amount DAI deposited since last distribution;
    mapping (address => uint256) withdrawalsSinceLastDistribution;               // Amount DAI withdrawn since last distribution;

    function initialize(address _pool) public initializer {
        Module.initialize(_pool);
        DefiOperatorRole.initialize(_msgSender());
        //_createInitialDistribution();
    }

    // == Public functions
    function handleDeposit(address token, address sender, uint256 amount) public onlyDefiOperator {
        depositsSinceLastDistribution[token] = depositsSinceLastDistribution[token].add(amount);
        handleDepositInternal(token, sender, amount);
        emit Deposit(amount);
    }


    function withdraw(address token, address beneficiary, uint256 amount) public onlyDefiOperator {
        withdrawalsSinceLastDistribution[token] = withdrawalsSinceLastDistribution.add(amount);
        withdrawInternal(token, beneficiary, amount);
        emit Withdraw(amount);
    }

    function withdrawInterest(address token) public {
        _createDistributionIfReady(token);
        _updateUserBalance(token, _msgSender(), distributions.length);
        InvestmentBalance storage ib = balances[token][_msgSender()];
        if (ib.availableBalance > 0) {
            uint256 amount = ib.availableBalance;
            ib.availableBalance = 0;
            withdrawInternal(token, _msgSender(), amount);
            emit WithdrawInterest(_msgSender(), amount);
        }
    }

    /**
     * @notice Update state of user balance for next distributions
     * @param account Address of the user
     * @param balance New balance of the user
     */
    function updateBalance(address token, address account, uint256 balance) public {
        //require(_msgSender() == getModuleAddress(MODULE_PTOKEN), "DefiModuleBase: operation only allowed for PToken");
        _createDistributionIfReady(token);
        _updateUserBalance(token, account, distributions.length);
        balances[token][account].balance = balance;
        emit UserBalanceUpdated(account, balance);
    }

     /**
     * @notice Full token balance of the pool. Useful to transfer all funds to another module.
     * @dev Note, this call MAY CHANGE state  (internal DAI balance in Compound, for example)
     */
    function poolBalance(address token) public returns(uint256) {
        return poolBalanceOf(token);
    }

    /**
     * @notice Update user balance with interest received
     * @param account Address of the user
     */
    function claimDistributions(address token, address account) public {
        _createDistributionIfReady(token);
        _updateUserBalance(account, distributions[token].length);
    }

    function claimDistributions(address token, address account, uint256 toDistribution) public {
        require(toDistribution <= distributions[token].length, "DefiModuleBase: lastDistribution too hight");
        _updateUserBalance(token, account, toDistribution);
    }

    /**
     * @notice Returns how many DAI can be withdrawn by withdrawInterest()
     * @param account Account to check
     * @return Amount of DAI which will be withdrawn by withdrawInterest()
     */
    function availableInterest(address token, address account) public view returns (uint256) {
        InvestmentBalance storage ib = balances[token][account];
        uint256 unclaimed = _calculateDistributedAmount(ib.nextDistribution, distributions[token].length, ib.balance);
        return ib.availableBalance.add(unclaimed);
    }

    function distributionsLength(address token) public view returns(uint256) {
        return distributions[token].length;
    }

    // == Abstract functions to be defined in realization ==
    function handleDepositInternal(address token, address sender, uint256 amount) internal;
    function withdrawInternal(address token, address beneficiary, uint256 amount) internal;
    function poolBalanceOf(address token) internal /*view*/ returns(uint256); //This is not a view function because cheking cDAI balance may update it
    function totalSupplyOf(address token) internal view returns(uint256);
   

    // == Internal functions of DefiModule
    function _createInitialDistribution(address token) internal {
        assert(distributions[token].length == 0);
      
        distributions[token].push(Distribution({
            amount:0,
            balance: 0,
            total: 0
        }));
    }

    function _createDistributionIfReady(address token) internal {
        if (now < nextDistributionTimestamp) return;
        _createDistribution(token);
    }

    function _createDistribution(token) internal {
        Distribution storage prev = distributions[token][distributions.length - 1]; //This is safe because _createInitialDistribution called in initialize.
        uint256 currentBalanceOfToken = poolBalanceOf(token);
        uint256 total = totalSupplyOf(token);

        // // This calculation expects that, without deposit/withdrawals, DAI balance can only be increased
        // // Such assumption may be wrong if underlying system (Compound) is compromised.
        // // In that case SafeMath will revert transaction and we will have to update our logic.
        // uint256 distributionAmount =
        //     currentBalanceOfDAI
        //     .add(withdrawalsSinceLastDistribution)
        //     .sub(depositsSinceLastDistribution)
        //     .sub(prev.balance);
        uint256 a = currentBalanceOfToken.add(withdrawalsSinceLastDistribution[token]);
        uint256 b = depositsSinceLastDistribution.add(prev.balance);
        uint256 distributionAmount;
        if (a > b) {
            distributionAmount = a - b;
        }
        // else { //For some reason our balance on underlying system decreased (for example - on first deposit, because of rounding)
        //     distributionAmount = 0; //it is already 0
        // }

        if (distributionAmount == 0) return;

        distributions.push(Distribution({
            amount:distributionAmount,
            balance: currentBalanceOfToken,
            total: total
        }));
        depositsSinceLastDistribution[token] = 0;
        withdrawalsSinceLastDistribution[token] = 0;
        nextDistributionTimestamp = now.sub(now % DISTRIBUTION_AGGREGATION_PERIOD).add(DISTRIBUTION_AGGREGATION_PERIOD);
        emit InvestmentDistributionCreated(distributionAmount, currentBalanceOfToken, total);
    }


    /******** refactoring **********/
    function _updateUserBalance(address token, address account, uint256 toDistribution) internal {
        InvestmentBalance storage ib = balances[token][account];
        uint256 fromDistribution = ib.nextDistribution;
        uint256 interest = _calculateDistributedAmount(token, fromDistribution, toDistribution, ib.balance);
        ib.availableBalance = ib.availableBalance.add(interest);
        ib.nextDistribution = toDistribution;
        emit InvestmentDistributionsClaimed(account, ib.Balance, interest, fromDistribution, toDistribution);
    }

    function _calculateDistributedAmount(address token, uint256 fromDistribution, uint256 toDistribution, uint256 balance) internal view returns(uint256) {
        if (balance == 0) return 0;
        uint256 next = fromDistribution;
        uint256 totalInterest;
        while (next < toDistribution) {
            Distribution storage d = distributions[token][next];
            totalInterest = totalInterest.add(d.amount.mul(balance).div(d.total)); 
            next++;
        }
        return totalInterest;
    }
}