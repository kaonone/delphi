pragma solidity ^0.5.12;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";

/**
 * @dev Double linked list with address items
 */
library Normalization {
    using SafeMath for uint256;

    // decimal  - original decimals
    function normalize(uint256 amount, uint256 decimals)
        internal
        pure
        returns (uint256)
    {
        if (decimals == 18) {
            return amount;
        } else if (decimals > 18) {
            return amount.div(10**(decimals - 18));
        } else if (decimals < 18) {
            return amount.mul(10**(18 - decimals));
        }
    }

    // decimal  - final decimals
    function denormalize(uint256 amount, uint256 decimals)
        internal
        pure
        returns (uint256)
    {
        if (decimals == 18) {
            return amount;
        } else if (decimals > 18) {
            return amount.mul(10**(decimals - 18));
        } else if (decimals < 18) {
            return amount.div(10**(18 - decimals));
        }
    }
}
