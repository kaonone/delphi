pragma solidity ^0.5.17;

contract IDCAFullBalanceHelper {
    function getFullAccountBalances(address dcaModule, address account)
        external
        returns (address[] memory, uint256[] memory);
}
