pragma solidity ^0.5.12;

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "../../interfaces/defi/IUniswapV2Router.sol";
import "../../interfaces/defi/IUniswapV2Pair.sol";
import "../../common/Module.sol";
import "./DefiOperatorRole.sol";
import "./ProtocolBase.sol";

/**
 * RAY Protocol support module which works with only one base token
 */
contract UniswapV2Protocol is ProtocolBase {
    uint256 constant MAX_UINT256 = uint256(-1);

    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IUniswapV2Router public router;
    IUniswapV2Pair public pair;
    address[] registeredTokens;

    function initialize(address _pool) public initializer {
        ProtocolBase.initialize(_pool);
    }

    function setUniswapPool(address _router, address[] memory tokens) public onlyDefiOperator {
        require(tokens.length == 2, "UniswapV2Protocol: accept only 2 tokens");
        registeredTokens = tokens;
        router = IUniswapV2Router(_router);
        address factory = router.factory();
        pair = IUniswapV2Pair(uniswapPairFor(factory, tokens[0], tokens[1]));
        pair.approve(address(router), MAX_UINT256);
        IERC20(tokens[0]).safeApprove(address(router), MAX_UINT256);        
        IERC20(tokens[1]).safeApprove(address(router), MAX_UINT256);
    }

    function handleDeposit(address, address, uint256) public onlyDefiOperator {
        revert("UniswapV2Protocol: one token deposit not supported");
    }

    function handleDeposit(address beneficiary, address[] memory tokens, uint256[] memory amounts) public onlyDefiOperator {
        require(tokens.length == 2, "UniswapV2Protocol: accept only 2 tokens");
        require(tokens.length == amounts.length, "UniswapV2Protocol: accept only 2 tokens");

        (uint amountA, uint amountB,) = router.addLiquidity(
            tokens[0], tokens[1], 
            amounts[0], amounts[1], 
            0, 0,
            address(this), MAX_UINT256
        );

        // Refund
        if(amountA < amounts[0]){
            IERC20(tokens[0]).safeTransfer(beneficiary, amounts[0]-amountA);
        }
        if(amountB < amounts[1]){
            IERC20(tokens[1]).safeTransfer(beneficiary, amounts[1]-amountB);
        }
    }

    function withdraw(address, address, uint256) public onlyDefiOperator {
        revert("UniswapV2Protocol: one token withdraw not supported");
    }

    function withdraw(address beneficiary, uint256[] memory amounts) public onlyDefiOperator {
        require(amounts.length == 2, "UniswapV2Protocol: accept only 2 tokens");

        //uint256 pairBalance = pair.balanceOf(address(this));
        uint256 pairTS = pair.totalSupply();

        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();

        require(amounts[0] <= uint256(reserve0), "UniswapV2Protocol: not enough liquidity for token A");
        require(amounts[1] <= uint256(reserve1), "UniswapV2Protocol: not enough liquidity for token B");

        uint256 amnt = pairTS.mul(amounts[0]).div(reserve0); // amnt/pairTS = amounts[0]/reserve0
        //require(amnt <= pairBalance, "UniswapProtocol: not enough pool balance");
        require(amounts[1] == uint256(reserve1).mul(amnt).div(pairTS), "UniswapV2Protocol: wrong amount of token B");

        (uint amountA, uint amountB) = router.removeLiquidity(
            registeredTokens[0], registeredTokens[1], 
            amnt, 
            amounts[0], amounts[1], 
            address(this), MAX_UINT256
        );

        IERC20(registeredTokens[0]).safeTransfer(beneficiary, amountA);
        IERC20(registeredTokens[1]).safeTransfer(beneficiary, amountB);
    }

    function balanceOf(address token) public returns(uint256) {
        uint256 pairBalance = pair.balanceOf(address(this));
        uint256 pairTS = pair.totalSupply();

        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
        uint256 tBalance;
        if (token == registeredTokens[0]) {
            tBalance = uint256(reserve0);
        } else if (token == registeredTokens[1]) {
            tBalance = uint256(reserve1);
        } else{
            revert("UniswapV2Protocol: Unsupported token");
        }

        return pairBalance.mul(tBalance).div(pairTS); // ourTBalance/tBalance = ourPairBalance/pairTS
    }
    
    function balanceOfAll() public returns(uint256[] memory amnts) {
        uint256 pairBalance = pair.balanceOf(address(this));
        uint256 pairTS = pair.totalSupply();

        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
        amnts = new uint256[](2);
        amnts[0] = uint256(reserve0).mul(pairBalance).div(pairTS);
        amnts[1] = uint256(reserve1).mul(pairBalance).div(pairTS);
        return amnts;
    }

    function normalizedBalance() public returns(uint256) {
        return pair.balanceOf(address(this));
    }


    function canSwapToToken(address token) public view returns(bool) {
        return (token == registeredTokens[0] || token == registeredTokens[1]);
    }    

    function supportedTokens() public view returns(address[] memory){
        return registeredTokens;
    }

    function supportedTokensCount() public view returns(uint256) {
        return registeredTokens.length;
    }

    function getTokenIndex(address token) public view returns(uint256) {
        if (token == registeredTokens[0]) {
            return 0;
        } else if (token == registeredTokens[1]) {
            return 1;
        } else{
            revert("UniswapV2Protocol: Unsupported token");
        }
    }

    function supportedRewardTokens() public view returns(address[] memory) {
        address[] memory rtkns = new address[](0);
        return rtkns;
    }

    function isSupportedRewardToken(address) public view returns(bool) {
        return false;
    }

    function cliamRewardsFromProtocol() internal {
        //do nothing, rewards not supported
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


    /**
     * @notice returns sorted token addresses, used to handle return values from pairs sorted in this order
     * Source: https://github.com/Uniswap/uniswap-v2-periphery/blob/master/contracts/libraries/UniswapV2Library.sol
     */
    function uniswapSortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'UniswapV2Protocol: UniswapV2Library: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'UniswapV2Protocol: UniswapV2Library: ZERO_ADDRESS');
    }

    /**
     * @notice calculates the CREATE2 address for a pair without making any external calls
     * Source: https://github.com/Uniswap/uniswap-v2-periphery/blob/master/contracts/libraries/UniswapV2Library.sol
     */
    function uniswapPairFor(address factory, address tokenA, address tokenB) internal pure returns (address _pair) {
        (address token0, address token1) = uniswapSortTokens(tokenA, tokenB);
        _pair = address(uint(keccak256(abi.encodePacked(
                hex'ff',
                factory,
                keccak256(abi.encodePacked(token0, token1)),
                hex'96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f' // init code hash
            ))));
    }


}
