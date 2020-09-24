pragma solidity ^0.5.12;

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Detailed.sol";

library CalcUtils {

    function normalizeAmount(address coin, uint256 amount) internal view returns(uint256){
        uint8 decimals = ERC20Detailed(coin).decimals();
        if (decimals < 18) {
            return amount * uint256(10)**(18-decimals);
        } else if (decimals > 18) {
            return amount / uint256(10)**(decimals-18);
        } else {
            return amount;
        }
    }

}