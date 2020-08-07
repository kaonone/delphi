pragma solidity ^0.5.17;

interface IDCAModule {
    // GETTERS
    function tokenToSell() external view returns (address);

    function tokensToBuy() external view returns (address[] memory);

    function rewardPools() external view returns (address[] memory);

    function getTokenIdByAddress(address userAddress)
        external
        view
        returns (uint256);

    function getAccountBuyAmount(uint256 tokenId) external returns (uint256);

    function getFullAccountBalances(address account, address[] calldata tokens)
        external
        returns (uint256[] memory);

    function getFullAccountBalances(
        address dcaFullBalanceHelper,
        address account
    ) external returns (address[] memory, uint256[] memory);

    // SETTERS
    function setTokenData(
        address token,
        uint256 decimals,
        address pool,
        address protocol,
        address poolToken
    ) external returns (bool);

    function setDeadline(uint256 newDeadline) external;

    function setProtocolMaxFee(uint256 maxFee) external;

    // CORE
    function deposit(uint256 amount, uint256 newBuyAmount)
        external
        returns (uint256, uint256);

    function withdraw(address token, uint256 amount)
        external
        returns (uint256, uint256);

    function purchase() external;
}
