pragma solidity ^0.5.12;

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "../../interfaces/defi/IDefiProtocol.sol";
import "../../interfaces/defi/IRAYStorage.sol";
import "../../interfaces/defi/IRAYPortfolioManager.sol";
import "../../interfaces/defi/IRAYNAVCalculator.sol";
import "./ProtocolBase.sol";

/**
 * RAY Protocol support module which works with only one base token
 */
contract RAYProtocol is ProtocolBase {
    bytes32 internal constant PORTFOLIO_MANAGER_CONTRACT = keccak256("PortfolioManagerContract");
    bytes32 internal constant NAV_CALCULATOR_CONTRACT = keccak256("NAVCalculatorContract");
    bytes32 internal constant RAY_TOKEN_CONTRACT = keccak256("RAYTokenContract");
    bytes4 internal constant ERC721_RECEIVER = bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
    uint256 constant MAX_UINT256 = uint256(-1);

    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IERC20 baseToken;
    uint8 decimals;
    bytes32 portfolioId;
    bytes32 rayTokenId;

    function initialize(address _pool, address _token, bytes32 _portfolioId) public initializer {
        ProtocolBase.initialize(_pool);
        baseToken = IERC20(_token);
        portfolioId = _portfolioId;
        decimals = ERC20Detailed(_token).decimals();

        IRAYPortfolioManager pm = rayPortfolioManager();
        IERC20(_token).safeApprove(address(pm), MAX_UINT256);
    }

    function onERC721Received(address, address, uint256, bytes memory) public view returns (bytes4) {
        address rayTokenContract = rayStorage().getContractAddress(RAY_TOKEN_CONTRACT);
        require(_msgSender() == rayTokenContract, "RAYModule: only accept RAY Token transfers");
        return ERC721_RECEIVER;
    }

    function handleDeposit(address token, uint256 amount) public onlyDefiOperator {
        require(token == address(baseToken), "RAYProtocol: token not supported");
        IRAYPortfolioManager pm = rayPortfolioManager();
        if (rayTokenId == 0x0) {
            rayTokenId = pm.mint(portfolioId, address(this), amount);
        } else {
            pm.deposit(rayTokenId, amount);
        }
    }

    function handleDeposit(address[] memory tokens, uint256[] memory amounts) public onlyDefiOperator {
        require(tokens.length == 1 && amounts.length == 1, "RAYProtocol: wrong count of tokens or amounts");
        handleDeposit(tokens[0], amounts[0]);
    }

    function withdraw(address beneficiary, address token, uint256 amount) public onlyDefiOperator {
        require(token == address(baseToken), "RAYProtocol: token not supported");
        rayPortfolioManager().redeem(rayTokenId, amount, address(0));
        IERC20(token).transfer(beneficiary, amount);
    }

    function withdraw(address beneficiary, uint256[] memory amounts) public onlyDefiOperator {
        require(amounts.length == 1, "RAYProtocol: wrong amounts array length");
        rayPortfolioManager().redeem(rayTokenId, amounts[0], address(0));
        IERC20(baseToken).safeTransfer(beneficiary, amounts[0]);
    }

    function balanceOf(address token) public returns(uint256) {
        if (token != address(baseToken)) return 0;
        if (rayTokenId == 0x0) return 0;
        (uint256 amount,) = rayNAVCalculator().getTokenValue(portfolioId, rayTokenId);
        return amount;
    }
    
    function balanceOfAll() public returns(uint256[] memory) {
        uint256[] memory balances = new uint256[](1);
        balances[0] = balanceOf(address(baseToken));
        return balances;
    }

    function normalizedBalance() public returns(uint256) {
        return normalizeAmount(address(baseToken), balanceOf(address(baseToken)));
    }

    function optimalProportions() public returns(uint256[] memory) {
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1e18;
        return amounts;
    }

    function canSwapToToken(address token) public view returns(bool) {
        return (token == address(baseToken));
    }    

    function supportedTokens() public view returns(address[] memory){
        address[] memory tokens = new address[](1);
        tokens[0] = address(baseToken);
        return tokens;
    }

    function supportedTokensCount() public view returns(uint256) {
        return 1;
    }

    function cliamRewardsFromProtocol() internal {
        this; //do nothing
    }

    function normalizeAmount(address, uint256 amount) internal view returns(uint256) {
        if (decimals == 18) {
            return amount;
        } else if (decimals > 18) {
            return amount.div(10**(uint256(decimals)-18));
        } else if (decimals < 18) {
            return amount.mul(10**(18-uint256(decimals)));
        }
    }

    function denormalizeAmount(address, uint256 amount) internal view returns(uint256) {
        if (decimals == 18) {
            return amount;
        } else if (decimals > 18) {
            return amount.mul(10**(uint256(decimals)-18));
        } else if (decimals < 18) {
            return amount.div(10**(18-uint256(decimals)));
        }
    }

    function rayPortfolioManager() private view returns(IRAYPortfolioManager){
        return rayPortfolioManager(rayStorage());
    }

    function rayPortfolioManager(IRAYStorage rayStorage) private view returns(IRAYPortfolioManager){
        return IRAYPortfolioManager(rayStorage.getContractAddress(PORTFOLIO_MANAGER_CONTRACT));
    }

    function rayNAVCalculator() private view returns(IRAYNAVCalculator){
        return rayNAVCalculator(rayStorage());
    }

    function rayNAVCalculator(IRAYStorage rayStorage) private view returns(IRAYNAVCalculator){
        return IRAYNAVCalculator(rayStorage.getContractAddress(NAV_CALCULATOR_CONTRACT));
    }

    function rayStorage() private view returns(IRAYStorage){
        return IRAYStorage(getModuleAddress(CONTRACT_RAY));
    }
}
