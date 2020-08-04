pragma solidity ^0.5.12;

contract ICurveFiDeposit_SUSD { 
    function add_liquidity (uint256[4] calldata uamounts, uint256 min_mint_amount) external;
    function remove_liquidity (uint256 _amount, uint256[4] calldata min_uamounts) external;
    function remove_liquidity_imbalance (uint256[4] calldata uamounts, uint256 max_burn_amount) external;
}