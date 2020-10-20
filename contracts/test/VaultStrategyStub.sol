pragma solidity ^0.5.12;

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";

import "../modules/defi/DefiOperatorRole.sol";
import "../interfaces/defi/IDefiStrategy.sol";
import "../interfaces/defi/IVaultProtocol.sol";
import "../utils/CalcUtils.sol";

contract VaultStrategyStub is IDefiStrategy, DefiOperatorRole {
    using SafeMath for uint256;

    address protocolStub;
    address vault;

    string internal strategyId;

    function initialize(string memory _strategyId) public initializer {
        DefiOperatorRole.initialize(msg.sender);
        strategyId = _strategyId;
    }

    function setProtocol(address _protocol) public onlyDefiOperator {
        protocolStub = _protocol;
    }

    function setVault(address _vault) public onlyDefiOperator {
        vault = _vault;
    }

    function handleDeposit(address token, uint256 amount) public onlyDefiOperator {
        IERC20(token).transferFrom(vault, protocolStub, amount);
    }

    function handleDeposit(address[] memory tokens, uint256[] memory amounts) public onlyDefiOperator {
        for (uint256 i = 0; i < tokens.length; i++) {
            handleDeposit(tokens[i], amounts[i]);
        }
    }

    function withdraw(address beneficiary, address token, uint256 amount) public {
        IERC20(token).transferFrom(protocolStub, beneficiary, amount);
    }

    function withdraw(address beneficiary, uint256[] memory amounts) public {
        address[] memory registeredVaultTokens = IVaultProtocol(vault).supportedTokens();

        for (uint256 i = 0; i < registeredVaultTokens.length; i++) {
            IERC20(registeredVaultTokens[i]).transferFrom(protocolStub, beneficiary, amounts[i]);
        }
    }

    function balanceOf(address token) public returns(uint256) {
        return IERC20(token).balanceOf(protocolStub);
    }
    function balanceOfAll() external returns(uint256[] memory balances) {
        address[] memory registeredVaultTokens = IVaultProtocol(vault).supportedTokens();
        balances = new uint256[](registeredVaultTokens.length);
        for (uint256 i=0; i < registeredVaultTokens.length; i++){
            balances[i] = IERC20(registeredVaultTokens[i]).balanceOf(protocolStub);
        }
    }

    function normalizedBalance() public returns(uint256) {
        address[] memory registeredVaultTokens = IVaultProtocol(vault).supportedTokens();
        uint256 summ;
        uint256 balance;
        for (uint256 i=0; i < registeredVaultTokens.length; i++){
            balance = IERC20(registeredVaultTokens[i]).balanceOf(protocolStub);
            summ = summ.add(CalcUtils.normalizeAmount(registeredVaultTokens[i], balance));
        }
        return summ;
    }

    function getStrategyId() public view returns(string memory) {
        return strategyId;
    }
}
