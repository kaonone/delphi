pragma solidity ^0.5.12;

import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/GSN/Context.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Detailed.sol";




contract VestedAkro is Context, Initializable, Ownable, IERC20, ERC20Detailed {
    struct VestedBatch {
        uint256 amount;     // Full amount of AKRO vested in this batch
        uint256 start;      // Vesting start time;
        uint256 end;        // Vesting end time
        uint256 claimed;    // AKRO already claimed from this batch
    }

    struct Holder {
        VestedBatch[] batches;
    }


    IERC20 public akro;
    mapping(address => Holder) holders;


    function initialize(address _akro) public initializer {
        Ownable.initialize(_msgSender());
        ERC20Detailed.initialize("Vested AKRO", "vAKRO", 18);
        akro = IERC20(_akro);
    }

    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);




}