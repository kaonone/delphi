pragma solidity ^0.5.12;

contract ICurveFiDeposit_SBTC { 
    function add_liquidity (uint256[3] calldata uamounts, uint256 min_mint_amount) external;
    function remove_liquidity (uint256 _amount, uint256[3] calldata min_uamounts) external;
    function remove_liquidity_imbalance (uint256[3] calldata uamounts, uint256 max_burn_amount) external;
}