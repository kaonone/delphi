pragma solidity ^0.5.12;

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "../../interfaces/defi/IDefiProtocol.sol";
import "../../interfaces/defi/IBPool.sol";
import "../../common/Module.sol";
import "./DefiOperatorRole.sol";
import "./ProtocolBase.sol";

/**
 * RAY Protocol support module which works with only one base token
 */
contract BalancerProtocol is ProtocolBase {
    uint256 constant MAX_UINT256 = uint256(-1);
    uint256 constant ALLOWED_NAMOUNT_DIFF = 10; //10 wei diff is allowed for rounding purposes when comparing amounts to expected

    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct TokenInfo {
        uint256 idx;
        uint8 decimals;
        uint256 normalizedWeight;
    }

    IBPool public bpt; //Balancer pool
    IERC20 public bal; //Balancer reward token
    address[] public registeredTokens; //addresses of tokens in the pool
    mapping(address => TokenInfo) registeredTokensInfo; //Maps token addresses to their details

    function initialize(address _pool) public initializer {
        ProtocolBase.initialize(_pool);
    }

    function setBalancer(address _bpt, address _bal) public onlyDefiOperator {
        bpt = IBPool(_bpt);
        bal = IERC20(_bal);
        registeredTokens = bpt.getCurrentTokens();
        require(bpt.isFinalized(), "BalancerProtocol: only finalized pools supported");
        require(registeredTokens.length > 0, "BalancerProtocol: pool should have registered tokens");
        for(uint256 i=0; i<registeredTokens.length; i++){
            address tkn = registeredTokens[i];
            registeredTokensInfo[tkn] = TokenInfo({
                idx: i,
                decimals: ERC20Detailed(tkn).decimals(),
                normalizedWeight: bpt.getNormalizedWeight(tkn)
            });
            require(registeredTokensInfo[tkn].normalizedWeight > 0, "BalancerProtocol: weight can not be 0");
            IERC20(tkn).approve(address(bpt), MAX_UINT256);
        }
    }

    function handleDeposit(address token, uint256 amount) public onlyDefiOperator {
        bpt.joinswapExternAmountIn(token, amount, 0);
        // uint256 bptBalance = bpt.balanceOf(address(this));
        // expect(bptAmount == bptBalance, "BalancerProtocol: returned and received amount not match");
    }

    function handleDeposit(address[] memory tokens, uint256[] memory amounts) public onlyDefiOperator {
        (uint256[] memory amnts, uint256 nTotal) = translateAmountArrayToProtocolTokens(tokens, amounts);
        bool correctProportions = checkAmountProportions(amnts, nTotal);
        require(correctProportions, "BalancerProtocol: wrong proportions");
        // Calculate expected bpt amount
        uint256 minExpectedBpt = MAX_UINT256;
        for(uint256 i=0; i<tokens.length;i++){
            uint256 tBal = bpt.getBalance(tokens[i]);
            uint256 pbtTS = bpt.totalSupply();
            uint256 expectedBpt = amnts[i].mul(pbtTS).div(tBal); // expectedBpt/bpt.totalSupply() == amnts[i]/tBal
            if(expectedBpt < minExpectedBpt) minExpectedBpt = expectedBpt;
        }
        bpt.joinPool(minExpectedBpt, amnts);
    }

    function withdraw(address beneficiary, address token, uint256 amount) public onlyDefiOperator {
        bpt.exitswapExternAmountOut(token, amount, MAX_UINT256);
        IERC20(token).transfer(beneficiary, amount);
    }

    function withdraw(address beneficiary, uint256[] memory amounts) public onlyDefiOperator {
        (uint256[] memory amnts, uint256 nTotal) = translateAmountArrayToProtocolTokens(registeredTokens, amounts);
        bool correctProportions = checkAmountProportions(amnts, nTotal);
        require(correctProportions, "BalancerProtocol: wrong proportions");
        // Calculate expected bpt amount
        uint256 maxExpectedBpt = 0;
        for(uint256 i=0; i<registeredTokens.length;i++){
            uint256 tBal = bpt.getBalance(registeredTokens[i]);
            uint256 pbtTS = bpt.totalSupply();
            uint256 expectedBpt = amnts[i].mul(pbtTS).div(tBal); // expectedBpt/bpt.totalSupply() == amnts[i]/tBal
            if(expectedBpt > maxExpectedBpt) maxExpectedBpt = expectedBpt;
        }
        bpt.exitPool(maxExpectedBpt, amnts);
        //send tokens to user
        for(uint256 i=0; i<registeredTokens.length; i++){
            address tkn = registeredTokens[i];
            IERC20(tkn).transfer(beneficiary, amnts[i]);
        }
    }

    function balanceOf(address token) public returns(uint256) {
        uint256 bptBalance = bpt.balanceOf(address(this));
        uint256 bptTS = bpt.totalSupply();
        uint256 tBalance = bpt.getBalance(token);
        return bptBalance.mul(tBalance).div(bptTS); // ourTBalance/tBalance = bptBalance/bptTS
    }
    
    function balanceOfAll() public returns(uint256[] memory amnts) {
        uint256 bptBalance = bpt.balanceOf(address(this));
        uint256 bptTS = bpt.totalSupply();

        amnts = new uint256[](registeredTokens.length);
        for(uint256 i=0; i<registeredTokens.length;i++){
            uint256 tBalance = bpt.getBalance(registeredTokens[i]);
            amnts[i] = bptBalance.mul(tBalance).div(bptTS);
        }
    }

    function normalizedBalance() public returns(uint256) {
        return bpt.balanceOf(address(this));
    }

    function optimalProportions() public returns(uint256[] memory) {
        uint256[] memory amounts = new uint256[](registeredTokens.length);
        for(uint256 i=0; i<registeredTokens.length;i++){
            address token = registeredTokens[i];
            amounts[i] = registeredTokensInfo[token].normalizedWeight;
        }
        return amounts;
    }

    /**
     * @notice Returns balance converted to baseToken and normalized to 18 decimals.
     * Example: Pool of 50% BTC + 50% ETH. BaseToken - BTC.
     * This fuction will convert amount of ETH to BTC, 
     * so that "summ" will be total BPool balance in BTC.
     * Then it will calculate "our" part of that balance,
     * and then convert this number to 18 decimals.
     */
    function balanceConvertedTo(address baseToken) public view returns(uint256) {
        uint256 summ; //BPool balance of all tokens, converted to baseToken
        for (uint256 i=0; i < registeredTokens.length; i++){
            address tkn = registeredTokens[i];
            uint256 bbal = bpt.getBalance(tkn);
            if(tkn == baseToken){
                summ = summ.add(bbal);
            }else{
                uint256 rate = bpt.getSpotPriceSansFee(tkn, baseToken); //This will return conversion rate without fee
                uint256 converted = bbal.mul(1e18).div(rate);    //1e18 is used because rate has 18 decimals
                summ = summ.add(converted);
            }
        }
        uint256 bptBalance = bpt.balanceOf(address(this));
        uint256 bptTS = bpt.totalSupply();
        uint256 ourBalance = bptBalance.mul(summ).div(bptTS);
        return normalizeAmount(registeredTokensInfo[baseToken].decimals, ourBalance);
    }

    function canSwapToToken(address token) public view returns(bool) {
        return (registeredTokensInfo[token].normalizedWeight > 0); //can swap to all tokens in BPool
    }    

    function supportedTokens() public view returns(address[] memory){
        return registeredTokens;
    }

    function supportedTokensCount() public view returns(uint256) {
        return registeredTokens.length;
    }

    function getTokenIndex(address token) public view returns(uint256) {
        require(registeredTokensInfo[token].normalizedWeight > 0, "Unsupported token");
        return registeredTokensInfo[token].idx;
    }

    function supportedRewardTokens() public view returns(address[] memory) {
        uint256 defaultRTCount = defaultRewardTokensCount();
        address[] memory rtokens = new address[](defaultRTCount+1);
        rtokens = defaultRewardTokensFillArray(rtokens);
        rtokens[defaultRTCount] = address(bal);
        return rtokens;
    }

    function cliamRewardsFromProtocol() internal {
        //do nothing, Balancer will send BAL tokens itself
    }

    function translateAmountArrayToProtocolTokens(address[] memory tokens, uint256[] memory amounts) internal view returns(uint256[] memory amnts, uint256 nTotal) {
        amnts = new uint256[](registeredTokens.length);
        for(uint256 i=0; i<tokens.length;i++){
            address token = tokens[i];
            uint256 idx = getTokenIndex(token);
            amnts[idx] = amounts[i];
            nTotal = nTotal.add(normalizeAmount(registeredTokensInfo[token].decimals, amnts[idx]));
        }
    }
    function checkAmountProportions(uint256[] memory amnts, uint256 nTotal) internal view returns(bool){
        for(uint256 i=0; i<registeredTokens.length;i++){
            address token = registeredTokens[i];
            uint256 expectedNAmount = nTotal.mul(registeredTokensInfo[token].normalizedWeight).div(1e18);
            uint256 nAmount = normalizeAmount(registeredTokensInfo[token].decimals, amnts[i]);
            uint256 diff = (nAmount > expectedNAmount)?(nAmount - expectedNAmount):(expectedNAmount-nAmount);
            if(diff > ALLOWED_NAMOUNT_DIFF) return false;
        }
        return true;
    }

    function normalizeAmount(uint8 decimals, uint256 amount) internal pure returns(uint256) {
        if (decimals == 18) {
            return amount;
        } else if (decimals > 18) {
            return amount.div(10**(uint256(decimals)-18));
        } else if (decimals < 18) {
            return amount.mul(10**(18-uint256(decimals)));
        }
    }

    function denormalizeAmount(uint8 decimals, uint256 amount) internal pure returns(uint256) {
        if (decimals == 18) {
            return amount;
        } else if (decimals > 18) {
            return amount.mul(10**(uint256(decimals)-18));
        } else if (decimals < 18) {
            return amount.div(10**(18-uint256(decimals)));
        }
    }

}
