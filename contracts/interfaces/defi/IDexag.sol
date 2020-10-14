pragma solidity ^0.5.12;

/**
 * Interfce for Dexag Proxy
 * https://github.com/ConcourseOpen/DEXAG-Proxy/blob/master/contracts/DexTradingWithCollection.sol
 */
interface IDexag {
    function approvalHandler() external returns(address);

    function trade(
        address from,
        address to,
        uint256 fromAmount,
        address[] calldata exchanges,
        address[] calldata approvals,
        bytes calldata data,
        uint256[] calldata offsets,
        uint256[] calldata etherValues,
        uint256 limitAmount,
        uint256 tradeType
    ) external payable;

}

