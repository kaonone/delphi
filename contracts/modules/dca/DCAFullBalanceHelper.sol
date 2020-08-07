pragma solidity ^0.5.17;

import "../../interfaces/dca/IDCAModule.sol";
import "../../interfaces/savings/ISavingsModule.sol";

contract DCAFullBalanceHelper {
    mapping(address => mapping(address => bool)) public isInArray;
    mapping(address => address[]) public tokenArrayOf;

    function getFullAccountBalances(address dcaModule, address account)
        external
        returns (address[] memory, uint256[] memory)
    {
        _getAllCoreTokens(dcaModule);
        _getAllRewardTokens(dcaModule);

        address[] memory tokens = new address[](tokenArrayOf[dcaModule].length);

        for (uint256 i = 0; i < tokenArrayOf[dcaModule].length; i++) {
            tokens[i] = tokenArrayOf[dcaModule][i];
        }

        uint256[] memory balances = IDCAModule(dcaModule)
            .getFullAccountBalances(account, tokens);

        return (tokens, balances);
    }

    function _getAllCoreTokens(address dcaModule) private {
        address tokenToSell = IDCAModule(dcaModule).tokenToSell();
        address[] memory tokensToBuy = IDCAModule(dcaModule).tokensToBuy();

        _pushToArray(dcaModule, tokenToSell);

        for (uint256 i = 0; i < tokensToBuy.length; i++) {
            _pushToArray(dcaModule, tokensToBuy[i]);
        }
    }

    function _getAllRewardTokens(address dcaModule) private {
        address[] memory rewardPools = IDCAModule(dcaModule).rewardPools();

        for (uint256 i = 0; i < rewardPools.length; i++) {
            address[] memory rewardTokens = ISavingsModule(rewardPools[i])
                .supportedRewardTokens();

            for (uint256 j = 0; j < rewardTokens.length; j++) {
                _pushToArray(dcaModule, rewardTokens[j]);
            }
        }
    }

    function _pushToArray(address dcaModule, address token) private {
        if (!isInArray[dcaModule][token]) {
            tokenArrayOf[dcaModule].push(token);
            isInArray[dcaModule][token] = true;
        }
    }
}
