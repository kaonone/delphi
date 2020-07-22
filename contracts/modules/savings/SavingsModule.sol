pragma solidity ^0.5.12;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/lifecycle/Pausable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/SafeERC20.sol";
import "../../common/Module.sol";
import "../token/PoolToken.sol";

contract SavingsModule is Module {
    uint256 constant MAX_UINT256 = uint256(-1);

    using SafeERC20 for ERC20;
    using SafeMath for uint256;

    struct ProtocolInfo {
        uint256 previousPeriodAPY;
        uint256 periodStartTimestamp;
        uint256 periodStartBalance;
        uint256 depositsSincePeriodStart;
        uint256 withdrawalsSincePeriodStart;
    }

    struct TokenData {
        uint8 decimals;
        mapping(address => ProtocolInfo) protocols; //mapping of protocol to data we need to calculate APY
    }

    address[] registeredTokens;
    IDefiProtocol[] registeredProtocols;
    mapping(address => TokenData) tokens;
    mapping(address => address) poolTokens; // Mapping of IDefiProtocol to PoolToken

    function initialize(address _pool) public initializer {
        Module.initialize(_pool);
    }

    function registerProtocol(IDefiProtocol protocol, PoolToken poolToken) public onlyOwner {
        uint256 i;
        for (i = 0; i < registeredProtocols.length; i++){
            if (address(registeredProtocols[i]) == address(protocol)) revert("SavingsModule: protocol already registered");
        }
        registeredProtocols.push(protocol);
        poolTokens[address(protocol)] = poolToken;
        address[] memory supportedTokens = protocol.supportedTokens();
        for (i = 0; i < supportedTokens.length; i++){
            address tkn = supportedTokens[i];
            if (!isTokenRegistered(tkn)){
                registeredTokens.push(tkn);
            }
            tokens[tkn].decimals = ERC20Detailed(tkn).decimals();
            tokens[tkn].protocols[address(protocol)] = ProtocolInfo({
                previousPeriodAPY: 0,
                periodStartBalance: protocol.balanceOf(tkn),
                periodStartTimestamp: now,
                depositsSincePeriodStart: 0,
                withdrawalsSincePeriodStart: 0
            });
            IERC20(tkn).approve(address(protocol), MAX_UINT256);
        }
        uint256 normalizedBalance= protocol.normalizedBalance();
        if(normalizedBalance > 0) {
            uint256 ts = poolToken.totalSupply();
            if(ts < normalizedBalance) {
                poolToken.mint(_msgSender(), normalizedBalance.sub(ts));
            }
        }
    }

    /**
     * @notice Deposit tokens to a protocol
     * @param _protocol Protocol to deposit tokens
     * @param _tokens Array of tokens to deposit
     * @param _dnAmounts Array of amounts (denormalized to token decimals)
     */
    function deposit(address _protocol, address[] memory _tokens, uint256[] memory _dnAmounts) public {
        uint256 normalizedBalanceBefore = IDefiProtocol(_protocol).normalizedBalance();
        depositInternal(_protocol, _tokens, _dnAmounts);
        uint256 normalizedBalanceAfter = IDefiProtocol(_protocol).normalizedBalance();
        PoolToken poolToken = PoolToken(poolTokens[_protocol]);
        poolToken.mint(_msgSender(), normalizedBalanceAfter.sub(normalizedBalanceBefore));
    }

    function depositInternal(address _protocol, address[] memory _tokens, uint256[] memory _dnAmounts) internal {
        require(_tokens.length == _dnAmounts.length, "SavingsModule: count of tokens does not match count of amounts");
        for (uint256 i=0; i < _tokens.length; i++) {
            address tkn = _tokens[i];
            require(tokens[tkn].protocols[_protocol].periodStartTimestamp > 0, "SavingsModule: Token not registered for a protocol");
            IERC20(tkn).safeTransferFrom(_msgSender(), _protocol, _dnAmounts[i]);
        }
        protocol.deposit(_tokens, _dnAmounts);
    }

    /**
     * Withdraw tokens from protocol
     */
    function withdraw(address poolToken, uint256 amount) {
        IERC20.burnFrom(_msgSender(), amount);
        

    }



    function normalizeTokenAmount(address token, uint256 amount) private view returns(uint256) {
        uint8 decimals = tokens[token].decimals;
        if (decimals == 18) {
            return amount;
        } else if (decimals > 18) {
            return amount.div(10**(decimals-18));
        } else if (decimals > 18) {
            return amount.mul(10**(decimals-18));
        }
    }

    function denormalizeTokenAmount(address token, uint256 amount) private view returns(uint256) {
        uint8 decimals = tokens[token].decimals;
        if (decimals == 18) {
            return amount;
        } else if (decimals > 18) {
            return amount.mul(10**(decimals-18));
        } else if (decimals > 18) {
            return amount.div(10**(decimals-18));
        }
    }

}
