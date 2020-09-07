pragma solidity ^0.5.12;

import "./CurveFiProtocol.sol";
import "../../interfaces/defi/ICurveFiDeposit_Y.sol";
import "../../interfaces/defi/IYErc20.sol";

contract CurveFiProtocol_Y_Base is CurveFiProtocol {

    struct PriceData {
        uint256 price;
        uint256 lastUpdateBlock;
    }

    address[] public yTokens;
    mapping(address=>PriceData) internal yPricePerFullShare;

    function upgrade() public onlyOwner() {
        require(yTokens.length == 0, "CurveFiProtocol_Y_Base: already upgraded"); 
        for(uint256 i=0; i<_registeredTokens.length; i++) {
            address yToken = curveFiDeposit.coins(int128(i));
            yTokens.push(yToken);
        }
    }

    function setCurveFi(address deposit, address liquidityGauge) public onlyDefiOperator {
        super.setCurveFi(deposit, liquidityGauge);
        for(uint256 i=0; i<_registeredTokens.length; i++) {
            address yToken = curveFiDeposit.coins(int128(i));
            yTokens.push(yToken);
        }
    }

    function balanceOf(address token) public returns(uint256) {
        uint256 tokenIdx = getTokenIndex(token);

        uint256 cfBalance = curveFiTokenBalance();
        uint256 cfTotalSupply = curveFiToken.totalSupply();
        uint256 yTokenCurveFiBalance = curveFiSwap.balances(int128(tokenIdx));
        
        uint256 yTokenShares = yTokenCurveFiBalance.mul(cfBalance).div(cfTotalSupply);
        uint256 tokenBalance = getPricePerFullShare(yTokens[tokenIdx]).mul(yTokenShares).div(1e18); //getPricePerFullShare() returns balance of underlying token multiplied by 1e18

        return tokenBalance;
    }
    
    function balanceOfAll() public returns(uint256[] memory balances) {
        IERC20 cfToken = IERC20(curveFiDeposit.token());
        uint256 cfBalance = curveFiTokenBalance();
        uint256 cfTotalSupply = cfToken.totalSupply();

        balances = new uint256[](_registeredTokens.length);
        for (uint256 i=0; i < _registeredTokens.length; i++){
            uint256 ycfBalance = curveFiSwap.balances(int128(i));
            uint256 yShares = ycfBalance.mul(cfBalance).div(cfTotalSupply);
            balances[i] = getPricePerFullShare(yTokens[i]).mul(yShares).div(1e18); //getPricePerFullShare() returns balance of underlying token multiplied by 1e18
        }
    }

    function lastYPricePerFullShare(address yToken) public view returns(uint256 lastUpdateBlock, uint256 price) {
        PriceData storage pd = yPricePerFullShare[yToken];
        return (pd.lastUpdateBlock, pd.price);
    }

    function getPricePerFullShare(address yToken) internal returns(uint256) {
        PriceData storage pd = yPricePerFullShare[yToken];
        if(pd.lastUpdateBlock < block.number) {
            pd.price = IYErc20(yToken).getPricePerFullShare();
            pd.lastUpdateBlock = block.number;
        }
        return pd.price;
    }

    uint256[50] private ______gap;
}
