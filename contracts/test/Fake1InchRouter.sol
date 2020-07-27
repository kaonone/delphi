pragma solidity ^0.5.12;

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";

contract Fake1InchRouter {
    function getExpectedReturn(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount,
        uint256 parts,
        uint256 flags
    )
        public
        view
        returns (uint256 returnAmount, uint256[] memory distribution)
    {
        (fromToken, destToken, parts, flags);

        uint256[] memory dist = new uint256[](1);
        dist[0] = 1;

        return (amount, dist);
    }

    function swap(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount,
        uint256 minReturn,
        uint256[] memory distribution,
        uint256 flags
    ) public payable returns (uint256 returnAmount) {
        (fromToken, destToken, amount, distribution, flags);

        fromToken.transferFrom(msg.sender, address(this), amount);
        destToken.transfer(msg.sender, minReturn);

        return minReturn;
    }
}
