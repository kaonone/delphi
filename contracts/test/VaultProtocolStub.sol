pragma solidity ^0.5.12;

import "../modules/defi/VaultProtocol.sol";

contract VaultProtocolStub is VaultProtocol {
    address protocolStub;

    function registerTokens(address[] memory tokens) public onlyDefiOperator {
        for (uint256 i = 0; i < tokens.length; i++) {
            registeredVaultTokens.push(tokens[i]);
            claimableTokens.push(0);
        }
    }

    function setProtocol(address _protocol) public onlyDefiOperator {
        protocolStub = _protocol;
    }

    function handleDeposit(address token, uint256 amount) public onlyDefiOperator {
        IERC20(token).transfer(protocolStub, amount);
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
        for (uint256 i = 0; i < registeredVaultTokens.length; i++) {
            IERC20(registeredVaultTokens[i]).transferFrom(protocolStub, beneficiary, amounts[i]);
        }
    }
}
