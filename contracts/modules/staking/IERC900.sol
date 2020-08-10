pragma solidity ^0.5.12;


/**
 * @title ERC900 Simple Staking Interface
 * @dev See https://github.com/ethereum/EIPs/blob/master/EIPS/eip-900.md
 */
interface IERC900 {
  event Staked(address indexed user, uint256 amount, uint256 total, bytes data);
  event Unstaked(address indexed user, uint256 amount, uint256 total, bytes data);

  function stake(uint256 amount, bytes calldata data) external;

  function stakeFor(address user, uint256 amount, bytes calldata data) external;
  function unstake(uint256 amount, bytes calldata data) external;
  function totalStakedFor(address addr) external  view returns (uint256);
  function totalStaked() external  view returns (uint256);
  function token() external  view returns (address);
  function supportsHistory() external  pure returns (bool);

  // NOTE: Not implementing the optional functions
  // function lastStakedFor(address addr) external  view returns (uint256);
  // function totalStakedForAt(address addr, uint256 blockNumber) external  view returns (uint256);
  // function totalStakedAt(uint256 blockNumber) external  view returns (uint256);
}