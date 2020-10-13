pragma solidity ^0.5.12;

import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/GSN/Context.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/roles/MinterRole.sol";
import "./VestedAkroSenderRole.sol";

contract VestedAkro is Initializable, Context, Ownable, IERC20, ERC20Detailed, MinterRole, VestedAkroSenderRole {
    using SafeMath for uint256;

    struct VestedBatch {
        uint256 amount;     // Full amount of vAKRO vested in this batch
        uint256 start;      // Vesting start time;
        uint256 end;        // Vesting end time
        uint256 claimed;    // vAKRO already claimed from this batch
    }

    struct Balance {
        VestedBatch[] batches;  // Array of vesting batches
        uint256 locked;         // Amount locked in batches
        uint256 unlocked;       // Amount of unlocked vAKRO (which probably was previously claimed)
        uint256 firstUnclaimedBatch; // First batch which is not fully claimed
    }


    uint256 public totalSupply;
    IERC20 public akro;
    mapping(address => Balance) public holders;
    mapping (address => mapping (address => uint256)) private _allowances;
    uint256 public vestingPeriod;


    function initialize(address _akro, uint256 _vestingPeriod) public initializer {
        Ownable.initialize(_msgSender());
        VestedAkroSenderRole(_msgSender());
        ERC20Detailed.initialize("Vested AKRO", "vAKRO", 18);
        akro = IERC20(_akro);
        require(_vestingPeriod > 0, "VestedAkro: vestingPeriod should be > 0");
        vestingPeriod = _vestingPeriod;
    }

    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowances[owner][spender];
    }
    function approve(address spender, uint256 amount) public returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }
    function transferFrom(address sender, address recipient, uint256 amount) public returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "VestedAkro: transfer amount exceeds allowance"));
        return true;
    }

    function transfer(address recipient, uint256 amount) public onlySender returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function setVestingPeriod(uint256 _vestingPeriod) public onlyOwner {
        require(_vestingPeriod > 0, "VestedAkro: vestingPeriod should be > 0");
        vestingPeriod = _vestingPeriod;
    }

    function mint(address beneficiary, uint256 amount) public onlyMinter {
        akro.transferFrom(_msgSender(), address(this), amount);
        totalSupply = totalSupply.add(amount);
        holders[beneficiary].unlocked = holders[beneficiary].unlocked.add(amount);
        emit Transfer(address(0), beneficiary, amount);
    }

    function swapAllUnlocked() public {
        address beneficiary = _msgSender();
        claimAllFromBatches(beneficiary);
        uint256 amount = holders[beneficiary].unlocked;

        holders[beneficiary].unlocked = 0;
        totalSupply = totalSupply.sub(amount);
        akro.transfer(beneficiary, amount);
        emit Transfer(beneficiary, address(0), amount);
    }

    function balanceOf(address account) public view returns (uint256) {
        Balance storage b = holders[account];
        return b.locked.add(b.unlocked);
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "VestedAkro: approve from the zero address");
        require(spender != address(0), "VestedAkro: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "VestedAkro: transfer from the zero address");
        require(recipient != address(0), "VestedAkro: transfer to the zero address");

        holders[sender].unlocked = holders[sender].unlocked.sub(amount, "VestedAkro: transfer amount exceeds unlocked balance");
        createNewBatch(recipient, amount);

        emit Transfer(sender, recipient, amount);
    }


    function createNewBatch(address holder, uint256 amount) internal {
        Balance storage b = holders[holder];
        b.batches.push(VestedBatch({
            amount: amount,
            start: now,
            end: now.add(vestingPeriod),
            claimed: 0
        }));
        b.locked = b.locked.add(amount);
    }

    function claimAllFromBatches(address holder) internal {
        Balance storage b = holders[holder];
        bool firstUnclaimedFound;
        uint256 claiming;
        for(uint256 i = b.firstUnclaimedBatch; i < b.batches.length; i++) {
            (uint256 claimable, bool fullyClaimable) = calculateClaimableFromBatch(b.batches[i]);
            if(claimable > 0) {
                b.batches[i].claimed = b.batches[i].claimed.add(claimable);
                claiming = claiming.add(claimable);
            }
            if(!fullyClaimable && !firstUnclaimedFound) {
                b.firstUnclaimedBatch = i;
                firstUnclaimedFound = true;
            }
        }
        b.locked = b.locked.sub(claiming);
        b.unlocked = b.unlocked.add(claiming);
        if(!firstUnclaimedFound) {
            b.firstUnclaimedBatch = b.batches.length;
        }
    }

    /**
     * @notice Calculates one batch
     * @return claimable amount and bool which is true if batch is fully claimable
     */
    function calculateClaimableFromBatch(VestedBatch storage vb) internal view returns(uint256, bool) {
        //if(now < vb.start) return 0; // this should never happen becuse we have no cliff period
        if(now >= vb.end) {
            return (vb.amount.sub(vb.claimed), true);
        }
        uint256 claimable = (vb.amount.mul(now.sub(vb.start)).div(vb.end.sub(vb.start))).sub(vb.claimed);
        return (claimable, false);
    }
}