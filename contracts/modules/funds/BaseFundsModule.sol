pragma solidity ^0.5.12;

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "../../interfaces/curve/IFundsModule.sol";
import "../../common/Module.sol";
import "./FundsOperatorRole.sol";

//solhint-disable func-order
contract BaseFundsModule is Module, IFundsModule, FundsOperatorRole {
    using SafeMath for uint256;
    uint256 private constant MULTIPLIER = 1e18; // Price rate multiplier
    uint256 private constant STATUS_PRICE_AMOUNT = 10**18;  // Used to calculate price for Status event, should represent 1 DAI

    struct LTokenData {
        uint256 rate;   // Rate of the target token value to 1 USD, multiplied by MULTIPLIER. For DAI = 1e18, for USDC (6 decimals) = 1e30
        uint256 balance;    //Amount of this tokens on Pool balance
    }

    address[] public registeredLTokens;     // Array of registered LTokens (oreder is not significant and may change during removals)
    mapping(address=>LTokenData) public lTokens;   // Info about supported lTokens and their balances in Pool


    mapping (address => mapping (address => uint256)) accountLTokens;
    function initialize(address _pool) public initializer {
        Module.initialize(_pool);
        FundsOperatorRole.initialize(_msgSender());
        //lBalance = lToken.balanceOf(address(this)); //We do not initialize lBalance to preserve it's previous value when updgrade
    }

    /**
     * @notice Deposit liquid tokens to the pool
     * @param from Address of the user, who sends tokens. Should have enough allowance.
     * @param amount Amount of tokens to deposit
     */
    function depositLTokens(address token, address from, uint256 amount) public onlyFundsOperator {
        lTokens[token].balance = lTokens[token].balance.add(amount);
        accountLTokens[from][token] = accountLTokens[from][token].add(amount);
        lTransferToFunds(token, from, amount);
        emitStatus();
    }

    /**
     * @notice Withdraw liquid tokens from the pool
     * @param to Address of the user, who sends tokens. Should have enough allowance.
     * @param amount Amount of tokens to deposit
     */
    function withdrawLTokens(address token, address to, uint256 amount) public onlyFundsOperator {
        withdrawLTokens(token, to, amount, 0);
    }

    /**
     * @notice Withdraw liquid tokens from the pool
     * @param to Address of the user, who sends tokens. Should have enough allowance.
     * @param amount Amount of tokens to deposit
     * @param poolFee Pool fee will be sent to pool owner
     */
    function withdrawLTokens(address token, address to, uint256 amount, uint256 poolFee) public onlyFundsOperator {
        if (amount > 0) { //This will be false for "fee only" withdrawal in LiquidityModule.withdrawForRepay()
            lTokens[token].balance = lTokens[token].balance.sub(amount);
            accountLTokens[from][token] = accountLTokens[from][token].sub(amount);
            lTransferFromFunds(token, to, amount);
        }
        if (poolFee > 0) {
            lTokens[token].balance = lTokens[token].balance.sub(poolFee);
            lTransferFromFunds(token, owner(), poolFee);
        }
        emitStatus();
    }

    function registerLToken(address lToken, uint256 rate) public onlyOwner {
        require(rate != 0, "BaseFundsModule: bad rate");
        require(lTokens[lToken].rate == 0, "BaseFundsModule: already registered");
        registeredLTokens.push(lToken);
        lTokens[lToken] = LTokenData({rate: rate, balance: 0});
        emit LTokenRegistered(lToken, rate);
    }

    function unregisterLToken(address lToken) public onlyOwner {
        require(lTokens[lToken].rate != 0, "BaseFundsModule: token not registered");
        uint256 pos;
        //Find position of token we are removing
        for (pos = 0; pos < registeredLTokens.length; pos++) {
            if (registeredLTokens[pos] == lToken) break;
        }
        assert(registeredLTokens[pos] == lToken); // This should never fail because we know token is registered
        if (pos == registeredLTokens.length - 1) {
            // Removing last token
            registeredLTokens.pop();
        } else {
            // Replace token we are going to delete with the last one and remove it
            address last = registeredLTokens[registeredLTokens.length-1];
            registeredLTokens.pop();
            registeredLTokens[pos] = last;
        }
        emit LTokenUnregistered(lToken);
    }

    function setLTokenRate(address lToken, uint256 rate) public onlyOwner {
        require(rate != 0, "BaseFundsModule: bad rate");
        require(lTokens[lToken].rate != 0, "BaseFundsModule: token not registered");
        uint256 oldRate = lTokens[lToken].rate;
        lTokens[lToken].rate = rate;
        emit LTokenRateChanged(lToken, oldRate, rate);
    }

    function allRegisteredLTokens() external view returns(address[] memory){
        address[] memory tokens = new address[](registeredLTokens.length);
        for (uint256 i = 0; i < registeredLTokens.length; i++) {
            tokens[i] = registeredLTokens[i];
        }
        return tokens;
    }

    /**
     * @notice Refund liquid tokens accidentially sent directly to this contract
     * @param to Address of the user, who receives refund
     * @param amount Amount of tokens to send
     */
    function refundLTokens(address lToken, address to, uint256 amount) public onlyOwner {
        uint256 realLBalance = IERC20(lToken).balanceOf(address(this));
        require(realLBalance.sub(amount) >= lTokens[lToken].balance, "BaseFundsModule: not enough tokens to refund");
        require(IERC20(lToken).transfer(to, amount), "BaseFundsModule: refund failed");
    }

    function emitStatusEvent() public onlyFundsOperator {
        emitStatus();
    }

    function lBalance(address token) public view returns(uint256){
        return lTokens[token].balance;
    }

    function lBalance(address token, address account) public view returns(uint256) {
        return accountLTokens[account][token];
    }
    
    /**
     * Summmary balance of all lTokens, converted to USD multiplied by 1e18
     */
    function lBalance() public view returns(uint256) {
        uint256 lTotal;
        for (uint256 i = 0; i < registeredLTokens.length; i++) {
            LTokenData storage data = lTokens[registeredLTokens[i]];
            uint256 normalizedBalance = data.balance.mul(data.rate).div(MULTIPLIER);
            lTotal = lTotal.add(normalizedBalance);
        }
        return lTotal;
    }

    function getPrefferableTokenForWithdraw(uint256 lAmount) public view returns(address){
        //Use simplest strategy: return first one with enough liquitdity
        for (uint256 i = 0; i < registeredLTokens.length; i++) {
            LTokenData storage data = lTokens[registeredLTokens[i]];
            if (data.balance > lAmount) return registeredLTokens[i];
        }
        //If not found, just return first one
        return registeredLTokens[0];
    }

    function isLTokenRegistered(address token) public view returns(bool) {
        return  lTokens[token].rate != 0;
    }

    function normalizeLTokenValue(address token, uint256 value) public view returns(uint256) {
        LTokenData storage data = lTokens[token];
        return value.mul(data.rate).div(MULTIPLIER);     
    }

    function denormalizeLTokenValue(address token, uint256 value) public view returns(uint256) {
        LTokenData storage data = lTokens[token];
        return value.mul(MULTIPLIER).div(data.rate);     
    }

    function lTransferToFunds(address token, address from, uint256 amount) internal {
        require(IERC20(token).transferFrom(from, address(this), amount), "BaseFundsModule: incoming transfer failed");
    }

    function lTransferFromFunds(address token, address to, uint256 amount) internal {
        require(IERC20(token).transfer(to, amount), "BaseFundsModule: outgoing transfer failed");
    }

    function emitStatus() private {
        uint256 lBalanc = lBalance();
        uint256 lDebts = loanModule().totalLDebts();
        uint256 lProposals = loanProposalsModule().totalLProposals();
        uint256 pEnterPrice = curveModule().calculateEnter(lBalanc, lDebts, STATUS_PRICE_AMOUNT);
        uint256 pExitPrice; // = 0; //0 is default value
        if (lBalanc >= STATUS_PRICE_AMOUNT) {
            pExitPrice = curveModule().calculateExit(lBalanc.sub(lProposals), STATUS_PRICE_AMOUNT);
        } else {
            pExitPrice = 0;
        }
        emit Status(lBalanc, lDebts, lProposals, pEnterPrice, pExitPrice);
    } 
}
