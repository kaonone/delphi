pragma solidity ^0.5.12;

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";

import "../../common/Module.sol";
import "./DefiOperatorRole.sol";

import "../../interfaces/defi/IDefiStrategy.sol";
import "../../interfaces/defi/IStrategyCurveFiSwapCrv.sol";
import "../../interfaces/defi/IVaultProtocol.sol";
import "../../interfaces/defi/ICurveFiDeposit.sol";
import "../../interfaces/defi/ICurveFiDeposit_Y.sol";
import "../../interfaces/defi/ICurveFiLiquidityGauge.sol";
import "../../interfaces/defi/ICurveFiMinter.sol";
import "../../interfaces/defi/ICurveFiSwap.sol";
import "../../interfaces/defi/IDexag.sol";
import "../../interfaces/defi/IYErc20.sol";

import "../../utils/CalcUtils.sol";


contract CurveFiStablecoinStrategy is Module, IDefiStrategy, IStrategyCurveFiSwapCrv, DefiOperatorRole {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;


    struct PriceData {
        uint256 price;
        uint256 lastUpdateBlock;
    }

    address public vault;

    ICurveFiDeposit public curveFiDeposit;
    IERC20 public curveFiToken;
    ICurveFiLiquidityGauge public curveFiLPGauge;
    ICurveFiSwap public curveFiSwap;
    ICurveFiMinter public curveFiMinter;
    uint256 public slippageMultiplier;
    address public crvToken;
    
    address public dexagProxy;
    address public dexagApproveHandler;

    string internal strategyId;

    mapping(address=>PriceData) internal yPricePerFullShare;

    //Register stablecoins contracts addresses
    function initialize(address _pool, string memory _strategyId) public initializer {
        Module.initialize(_pool);
        DefiOperatorRole.initialize(_msgSender());
        slippageMultiplier = 1.01*1e18;
        strategyId = _strategyId;
    }

    function setProtocol(address _depositContract, address _liquidityGauge, address _curveFiMinter, address _dexagProxy) public onlyDefiOperator {
        require(_depositContract != address(0), "Incorrect deposit contract address");

        curveFiDeposit = ICurveFiDeposit(_depositContract);
        curveFiLPGauge = ICurveFiLiquidityGauge(_liquidityGauge);
        curveFiMinter = ICurveFiMinter(_curveFiMinter);
        curveFiSwap = ICurveFiSwap(curveFiDeposit.curve());

        curveFiToken = IERC20(curveFiDeposit.token());

        address lpToken = curveFiLPGauge.lp_token();
        require(lpToken == address(curveFiToken), "CurveFiProtocol: LP tokens do not match");

        crvToken = curveFiLPGauge.crv_token();

        dexagProxy = _dexagProxy;
        dexagApproveHandler = IDexag(_dexagProxy).approvalHandler();
    }

    function setVault(address _vault) public onlyDefiOperator {
        vault = _vault;
    }

    function setDexagProxy(address _dexagProxy) public onlyDefiOperator {
        dexagProxy = _dexagProxy;
        dexagApproveHandler = IDexag(_dexagProxy).approvalHandler();
    }

    function handleDeposit(address token, uint256 amount) public onlyDefiOperator {
        uint256 nTokens = IVaultProtocol(vault).supportedTokensCount();
        uint256[] memory amounts = new uint256[](nTokens);
        uint256 ind = IVaultProtocol(vault).tokenRegisteredInd(token);

        for (uint256 i=0; i < nTokens; i++) {
            amounts[i] = uint256(0);
        }
        IERC20(token).safeTransferFrom(vault, address(this), amount);
        IERC20(token).safeApprove(address(curveFiDeposit), amount);
        amounts[ind] = amount;

        ICurveFiDeposit_Y(address(curveFiDeposit)).add_liquidity(convertArray(amounts), 0);

        //Stake Curve LP-token
        uint256 cftBalance = curveFiToken.balanceOf(address(this));
        curveFiToken.safeApprove(address(curveFiLPGauge), cftBalance);
        curveFiLPGauge.deposit(cftBalance);
    }

    function handleDeposit(address[] memory tokens, uint256[] memory amounts) public onlyDefiOperator {
        require(tokens.length == amounts.length, "Count of tokens does not match count of amounts");
        require(amounts.length == IVaultProtocol(vault).supportedTokensCount(), "Amounts count does not match registered tokens");

        for (uint256 i=0; i < tokens.length; i++) {
            IERC20(tokens[i]).safeTransferFrom(vault, address(this), amounts[i]);
            IERC20(tokens[i]).safeApprove(address(curveFiDeposit), amounts[i]);
        }

        //Check for sufficient amounts on the Vault balances is checked in the WithdrawOperator()
        //Correct amounts are also set in WithdrawOperator()

        //Deposit stablecoins into the protocol
        ICurveFiDeposit_Y(address(curveFiDeposit)).add_liquidity(convertArray(amounts), 0);

        //Stake Curve LP-token
        uint256 cftBalance = curveFiToken.balanceOf(address(this));
        curveFiToken.safeApprove(address(curveFiLPGauge), cftBalance);
        curveFiLPGauge.deposit(cftBalance);
    }

    function withdraw(address beneficiary, address token, uint256 amount) public onlyDefiOperator {
        uint256 tokenIdx = IVaultProtocol(vault).tokenRegisteredInd(token);

        //All withdrawn tokens are marked as claimable, so anyway we need to withdraw from the protocol

            // count shares for proportional withdraw
        uint256 nAmount = CalcUtils.normalizeAmount(token, amount);
        uint256 nBalance = normalizedBalance();

        uint256 poolShares = curveFiTokenBalance();
        uint256 withdrawShares = poolShares.mul(nAmount).mul(slippageMultiplier).div(nBalance).div(1e18); //Increase required amount to some percent, so that we definitely have enough to withdraw
        
        //Currently on this contract
        uint256 notStaked = curveFiToken.balanceOf(address(this));
        //Unstake Curve LP-token
        if (notStaked < withdrawShares) { //Use available LP-tokens from previous yield
            curveFiLPGauge.withdraw(withdrawShares.sub(notStaked));
        }

        IERC20(curveFiToken).safeApprove(address(curveFiDeposit), withdrawShares);
        curveFiDeposit.remove_liquidity_one_coin(withdrawShares, int128(tokenIdx), amount, false); //DONATE_DUST - false

        IERC20(token).safeTransfer(beneficiary, amount);
    }

    function withdraw(address beneficiary, uint256[] memory amounts) public onlyDefiOperator {
        address[] memory registeredVaultTokens = IVaultProtocol(vault).supportedTokens();
        require(amounts.length == registeredVaultTokens.length, "Wrong amounts array length");

        //All withdrawn tokens are marked as claimable, so anyway we need to withdraw from the protocol
        uint256 nWithdraw;
        uint256 i;
        for (i = 0; i < registeredVaultTokens.length; i++) {
            address tkn = registeredVaultTokens[i];
            nWithdraw = nWithdraw.add(CalcUtils.normalizeAmount(tkn, amounts[i]));
        }

        uint256 nBalance = normalizedBalance();
        uint256 poolShares = curveFiTokenBalance();
        
        uint256 withdrawShares = poolShares.mul(nWithdraw).mul(slippageMultiplier).div(nBalance).div(1e18); //Increase required amount to some percent, so that we definitely have enough to withdraw

        //Unstake Curve LP-token
        curveFiLPGauge.withdraw(withdrawShares);

        IERC20(curveFiToken).safeApprove(address(curveFiDeposit), withdrawShares);
        ICurveFiDeposit_Y(address(curveFiDeposit)).remove_liquidity_imbalance(convertArray(amounts), withdrawShares);
        
        for (i = 0; i < registeredVaultTokens.length; i++){
            IERC20 lToken = IERC20(registeredVaultTokens[i]);
            uint256 lBalance = lToken.balanceOf(address(this));
            uint256 lAmount = (lBalance <= amounts[i])?lBalance:amounts[i]; // Rounding may prevent Curve.Fi to return exactly requested amount
            lToken.safeTransfer(beneficiary, lAmount);
        }
    }

    /**
     * @notice Operator should call this to receive CRV from curve
     */
    function performStrategyStep1() external onlyDefiOperator {
        claimRewardsFromProtocol();
        uint256 crvAmount = IERC20(crvToken).balanceOf(address(this));

        emit CrvClaimed(strategyId, address(this), crvAmount);
    }
    /**
     * @notice Operator should call this to exchange CRV to DAI
     */
    function performStrategyStep2(bytes calldata dexagSwapData, address swapStablecoin) external onlyDefiOperator {
        uint256 crvAmount = IERC20(crvToken).balanceOf(address(this));
        IERC20(crvToken).safeApprove(dexagApproveHandler, crvAmount);
        (bool success, bytes memory result) = dexagProxy.call(dexagSwapData);
        if(!success) assembly {
            revert(add(result,32), result)  //Reverts with same revert reason
        }
        //new dai tokens will be transferred to the Vault, they will be deposited by the operator on the next round
        //new LP tokens will be distributed automatically after the operator action
        uint256 amount = IERC20(swapStablecoin).balanceOf(address(this));
        IERC20(swapStablecoin).safeTransfer(vault, amount);
    }

    function curveFiTokenBalance() public view returns(uint256) {
        uint256 notStaked = curveFiToken.balanceOf(address(this));
        uint256 staked = curveFiLPGauge.balanceOf(address(this));
        return notStaked.add(staked);
    }

    function claimRewardsFromProtocol() internal {
        curveFiMinter.mint(address(curveFiLPGauge));
    }

    function balanceOf(address token) public returns(uint256) {
        uint256 tokenIdx = getTokenIndex(token);

        uint256 cfBalance = curveFiTokenBalance();
        uint256 cfTotalSupply = curveFiToken.totalSupply();
        uint256 yTokenCurveFiBalance = curveFiSwap.balances(int128(tokenIdx));
        
        uint256 yTokenShares = yTokenCurveFiBalance.mul(cfBalance).div(cfTotalSupply);
        uint256 tokenBalance = getPricePerFullShare(curveFiSwap.coins(int128(tokenIdx))).mul(yTokenShares).div(1e18); //getPricePerFullShare() returns balance of underlying token multiplied by 1e18

        return tokenBalance;
    }

    function balanceOfAll() public returns(uint256[] memory balances) {
        uint256 cfBalance = curveFiTokenBalance();
        uint256 cfTotalSupply = curveFiToken.totalSupply();
        uint256 nTokens = IVaultProtocol(vault).supportedTokensCount();

        require(cfTotalSupply > 0, "No Curve pool tokens minted");

        balances = new uint256[](nTokens);

        uint256 ycfBalance;
        for (uint256 i=0; i < nTokens; i++){
            ycfBalance =  curveFiSwap.balances(int128(i));
            uint256 yShares = ycfBalance.mul(cfBalance).div(cfTotalSupply);
            balances[i] = getPricePerFullShare(curveFiSwap.coins(int128(i))).mul(yShares).div(1e18);
        }
    }


    function normalizedBalance() public returns(uint256) {
        address[] memory registeredVaultTokens = IVaultProtocol(vault).supportedTokens();
        uint256[] memory balances = balanceOfAll();

        uint256 summ;
        for (uint256 i=0; i < registeredVaultTokens.length; i++){
            summ = summ.add(CalcUtils.normalizeAmount(registeredVaultTokens[i], balances[i]));
        }
        return summ;
    }

    function getStrategyId() public view returns(string memory) {
        return strategyId;
    }

    function convertArray(uint256[] memory amounts) internal pure returns(uint256[4] memory) {
        require(amounts.length == 4, "Wrong token count");
        uint256[4] memory amnts = [uint256(0), uint256(0), uint256(0), uint256(0)];
        for(uint256 i=0; i < 4; i++){
            amnts[i] = amounts[i];
        }
        return amnts;
    }

    function getTokenIndex(address token) public view returns(uint256) {
        address[] memory registeredVaultTokens = IVaultProtocol(vault).supportedTokens();
        for (uint256 i=0; i < registeredVaultTokens.length; i++){
            if (registeredVaultTokens[i] == token){
                return i;
            }
        }
        revert("CurveFiYProtocol: token not registered");
    }

    function getPricePerFullShare(address yToken) internal returns(uint256) {
        PriceData storage pd = yPricePerFullShare[yToken];
        if(pd.lastUpdateBlock < block.number) {
            pd.price = IYErc20(yToken).getPricePerFullShare();
            pd.lastUpdateBlock = block.number;
        }
        return pd.price;
    }
}
