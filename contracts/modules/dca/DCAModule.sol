pragma solidity ^0.5.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721Full.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721Mintable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721Burnable.sol";
import "@openzeppelin/contracts/drafts/Counters.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "../../interfaces/IUniswapV2Router02.sol";
import "../../TransferHelper.sol";
import "../../common/Module.sol";


contract DCAModule is ERC721Full, ERC721Mintable, ERC721Burnable {
    using SafeMath for uint256;
    using Counters for Counters.Counter;
    using TransferHelper for address;

    Counters.Counter private _tokenIds;

    struct BalanceAndBuyAmount {
        uint256 balance;
        uint256 buyAmount;
    }

    mapping(uint256 => BalanceAndBuyAmount) public _balanceAndBuyAmountOf;
    mapping(uint256 => bool) public activeTokens;

    enum Strategies {BTC, HALF, ETH}

    IERC20 public sellToken;
    IERC20 public buyToken;

    IUniswapV2Router02 public router;

    Strategies public currentStrategy;

    uint256 public globalPeriodBuyAmount;

    //  modifier operationAllowed(IAccessModule.Operation operation) {
    //     IAccessModule am = IAccessModule(getModuleAddress(MODULE_ACCESS));
    //     require(am.isOperationAllowed(operation, _msgSender()), "LiquidityModule: operation not allowed");
    //     _;
    // }

    // function initialize(address _pool) public initializer {
    //     Module.initialize(_pool);
    //     setLimits(10*10**18, 0);    //10 DAI minimal enter
    // }

    constructor(
        string memory name,
        string memory symbol
        address _sellToken,
        address _buyToken,
        uint256 _strategy,
        address _router
    ) public ERC721Full(name, symbol) {
        sellToken = IERC20(_sellToken);
        buyToken = IERC20(_buyToken);
        currentStrategy = Strategies(_strategy);
        router = IUniswapV2Router02(_router);
    }

    function deposit(uint256 amount, uint256 buyAmount) external {
        require(
            sellToken.transferFrom(_msgSender(), address(this), amount),
            "DCAModule: transferFrom error"
        );

        uint256 tokenId = _tokensOfOwner(msg.sender)[0];

        if (!activeTokens[tokenId]) {
            _tokenIds.increment();

            uint256 newItemId = _tokenIds.current();

            _mint(msg.sender, newItemId);

            _balanceAndBuyAmountOf[newItemId]
                .balance = _balanceAndBuyAmountOf[newItemId].balance.add(
                amount
            );

            _balanceAndBuyAmountOf[newItemId].buyAmount = buyAmount;

            activeTokens[newItemId] = true;

            globalPeriodBuyAmount = globalPeriodBuyAmount
                .sub(_balanceAndBuyAmountOf[newItemId].buyAmount)
                .add(buyAmount);
        } else {
            _balanceAndBuyAmountOf[tokenId]
                .balance = _balanceAndBuyAmountOf[tokenId].balance.add(amount);

            globalPeriodBuyAmount = globalPeriodBuyAmount
                .sub(_balanceAndBuyAmountOf[tokenId].buyAmount)
                .add(buyAmount);
        }
    }

    function buyBTC(address[] calldata path, uint256 deadline) external returns (bool) {
        require(
            uint256(currentStrategy) == uint256(Strategies.BTC),
            "DCAModule-buyBTC: wrong strategy"
        );

        path[0].safeApprove(router, globalPeriodBuyAmount);

        uint256 amountOutMin = router.getAmountsOut(
            globalPeriodBuyAmount,
            path
        )[1];

        router.swapExactTokensForTokens(
            globalPeriodBuyAmount,
            amountOutMin,
            path,
            address(this),
            deadline
        );

        return true;
    }

    function buyHALF() external returns (bool) {
        require(
            uint256(currentStrategy) == uint256(Strategies.HALF),
            "DCAModule-buyHALF: wrong strategy"
        );

        uint256 buyAmount = globalPeriodBuyAmount.div(2);

        path[0].safeApprove(router, buyAmount);

        uint256 amountOutMin = router.getAmountsOut(
            globalPeriodBuyAmount,
            path
        )[1];

        router.swapExactTokensForTokens(
                buyAmount,
                amountOutMin,
                path,
                address(this),
                deadline
            );

        path[0].safeApprove(router, buyAmount);

        uint256 amountOutMin = router.getAmountsOut(
            globalPeriodBuyAmount,
            path
        )[1];

        router.swapExactTokensForETH(
            buyAmount,
            amountOutMin,
            path,
            address(this),
            deadline
        );

        return true
    }

    function buyETH() external returns (bool) {
        require(
            uint256(currentStrategy) == uint256(Strategies.ETH),
            "DCAModule-buyETH: wrong strategy"
        );

        path[0].safeApprove(router, globalPeriodBuyAmount);

        uint256 amountOutMin = router.getAmountsOut(
            globalPeriodBuyAmount,
            path
        )[1];

        router.swapExactTokensForETH(
            globalPeriodBuyAmount,
            amountOutMin,
            path,
            address(this),
            deadline
        );

        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "ERC721: transfer caller is not owner or not approved"
        );

        _burn(from, tokenId);

        uint256 senderBalance = _balanceAndBuyAmountOf[tokenId].balance;

        _balanceAndBuyAmountOf[tokenId].balance = 0;

        uint256 recipientTokenId = _tokensOfOwner(to)[0];

        _balanceAndBuyAmountOf[recipientTokenId]
            .balance = _balanceAndBuyAmountOf[recipientTokenId].balance.add(
            senderBalance
        );

        activeTokens[tokenId] = false;
    }
}
