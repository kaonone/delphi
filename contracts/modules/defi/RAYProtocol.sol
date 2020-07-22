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
import "../../common/Module.sol";
import "./DefiOperatorRole.sol";

/**
 * RAY Protocol support module which works with only one base token
 */
contract RAYProtocol is Module, DefiOperatorRole, IERC721Receiver, IDefiProtocol {
    bytes32 internal constant PORTFOLIO_MANAGER_CONTRACT = keccak256("PortfolioManagerContract");
    bytes32 internal constant NAV_CALCULATOR_CONTRACT = keccak256("NAVCalculatorContract");
    bytes32 internal constant RAY_TOKEN_CONTRACT = keccak256("RAYTokenContract");
    bytes4 internal constant ERC721_RECEIVER = bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));

    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IERC20 baseToken;
    uint8 decimals;
    bytes32 portfolioId;
    bytes32 rayTokenId;

    function initialize(address _pool, address _token, bytes32 _portfolioId) public initializer {
        Module.initialize(_pool);
        DefiOperatorRole.initialize(_msgSender());
        baseToken = IERC20(_token);
        portfolioId = _portfolioId;
        decimals = ERC20Detailed(_token).decimals();
    }

    function onERC721Received(address, address, uint256, bytes memory) public returns (bytes4) {
        address rayTokenContract = rayStorage().getContractAddress(RAY_TOKEN_CONTRACT);
        require(_msgSender() == rayTokenContract, "RAYModule: only accept RAY Token transfers");
        return ERC721_RECEIVER;
    }

    function deposit(address token, uint256 amount) public onlyDefiOperator {
        require(token == address(baseToken), "RAYProtocol: token not supported");
        IERC20(token).safeTransferFrom(_msgSender(), address(this), amount);
        IRAYPortfolioManager pm = rayPortfolioManager();
        IERC20(token).safeApprove(address(pm), amount);
        if (rayTokenId == 0x0) {
            rayTokenId = pm.mint(portfolioId, address(this), amount);
        } else {
            pm.deposit(rayTokenId, amount);
        }
    }

    function deposit(address[] memory tokens, uint256[] memory amounts) public onlyDefiOperator {
        require(tokens.length == 1 && amounts.length == 1, "RAYProtocol: wrong count of tokens or amounts");
        deposit(tokens[0], amounts[0]);
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

    function normalizeAmount(address, uint256 amount) internal view returns(uint256) {
        if (decimals == 18) {
            return amount;
        } else if (decimals > 18) {
            return amount.div(10**(uint256(decimals)-18));
        } else if (decimals > 18) {
            return amount.mul(10**(uint256(decimals)-18));
        }
    }

    function denormalizeAmount(address, uint256 amount) internal view returns(uint256) {
        if (decimals == 18) {
            return amount;
        } else if (decimals > 18) {
            return amount.mul(10**(uint256(decimals)-18));
        } else if (decimals > 18) {
            return amount.div(10**(uint256(decimals)-18));
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
