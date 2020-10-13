pragma solidity ^0.5.12;

import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/GSN/Context.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/roles/MinterRole.sol";
import "./VestedAkroSenderRole.sol";

/**
 * @notice VestedAkro token represents AKRO token vested for a vestingPeriod set by owner of this VestedAkro token.
 * Generic holders of this token CAN NOT transfer it. They only can redeem AKRO from unlocked vAKRO.
 * Minters can mint unlocked vAKRO from AKRO to special VestedAkroSenders.
 * VestedAkroSender can send his unlocked vAKRO to generic holders, and this vAKRO will be vested. He can not redeem AKRO himself.
 */
contract VestedAkro is Initializable, Context, Ownable, IERC20, ERC20Detailed, MinterRole, VestedAkroSenderRole {
    using SafeMath for uint256;

    event Locked(address indexed holder, uint256 amount);
    event Unlocked(address indexed holder, uint256 amount);

    struct VestedBatch {
        uint256 amount;     // Full amount of vAKRO vested in this batch
        uint256 start;      // Vesting start time;
        uint256 end;        // Vesting end time
        uint256 claimed;    // vAKRO already claimed from this batch to unlocked balance of holder
    }

    struct Balance {
        VestedBatch[] batches;  // Array of vesting batches
        uint256 locked;         // Amount locked in batches
        uint256 unlocked;       // Amount of unlocked vAKRO (which either was previously claimed, or received from Minter)
        uint256 firstUnclaimedBatch; // First batch which is not fully claimed
    }

    uint256 public totalSupply;
    IERC20 public akro;
    uint256 public vestingPeriod; //set by owner of this VestedAkro token
    mapping (address => mapping (address => uint256)) private allowances;
    mapping (address => Balance) private holders;


    function initialize(address _akro, uint256 _vestingPeriod) public initializer {
        Ownable.initialize(_msgSender());
        MinterRole.initialize(_msgSender());
        VestedAkroSenderRole.initialize(_msgSender());
        ERC20Detailed.initialize("Vested AKRO", "vAKRO", 18);
        akro = IERC20(_akro);
        require(_vestingPeriod > 0, "VestedAkro: vestingPeriod should be > 0");
        vestingPeriod = _vestingPeriod;
    }

    function allowance(address owner, address spender) public view returns (uint256) {
        return allowances[owner][spender];
    }
    function approve(address spender, uint256 amount) public returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }
    function transferFrom(address sender, address recipient, uint256 amount) public onlySender returns (bool) {
        // We require both sender and _msgSender() to have VestedAkroSender role
        // to prevent sender from redeem and prevent unauthorized transfers via transferFrom.
        require(isSender(sender), "VestedAkro: sender should have VestedAkroSender role");

        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), allowances[sender][_msgSender()].sub(amount, "VestedAkro: transfer amount exceeds allowance"));
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

    /**
     * @notice Unlocks all avilable vAKRO for a holder
     * @param holder Whose funds to unlock
     * @param tillBatch Last batch to process + 1. Usually equal to batches.length
     * @return total unlocked amount awailable for redeem
     */
    function unlockAvailable(address holder, uint256 tillBatch) public returns(uint256) {
        require(tillBatch <= holders[holder].batches.length, "VestedAkro: tillBatch too high");
        claimAllFromBatches(holder);
        return holders[holder].unlocked;
    }

    /**
     * @notice Unlock all available vAKRO and redeem it
     * @return Amount redeemed
     */
    function unlockAndRedeemAll() public returns(uint256){
        address beneficiary = _msgSender();
        claimAllFromBatches(beneficiary);
        return redeemAllUnlocked();
    }

    /**
     * @notice Redeem all already unlocked vAKRO
     * @return Amount redeemed
     */
    function redeemAllUnlocked() public returns(uint256){
        address beneficiary = _msgSender();
        require(!isSender(beneficiary), "VestedAkro: VestedAkroSender is not allowed to redeem");
        uint256 amount = holders[beneficiary].unlocked;
        if(amount == 0) return 0;

        holders[beneficiary].unlocked = 0;
        totalSupply = totalSupply.sub(amount);
        akro.transfer(beneficiary, amount);
        emit Transfer(beneficiary, address(0), amount);
        return amount;
    }

    function balanceOf(address account) public view returns (uint256) {
        Balance storage b = holders[account];
        return b.locked.add(b.unlocked);
    }

    function balanceInfoOf(address account) public view returns(uint256 locked, uint256 unlocked, uint256 unlockable) {
        Balance storage b = holders[account];
        return (b.locked, b.unlocked, calculateClaimableFromBatches(account));
    }

    function batchesInfoOf(address account) public view returns(uint256 firstUnclaimedBatch, uint256 totalBatches) {
        Balance storage b = holders[account];
        return (b.firstUnclaimedBatch, b.batches.length);
    }

    function batchInfo(address account, uint256 batch) public view 
    returns(uint256 amount, uint256 start, uint256 end, uint256 claimed, uint256 claimable) {
        VestedBatch storage vb = holders[account].batches[batch];
        (claimable,) = calculateClaimableFromBatch(vb);
        return (vb.amount, vb.start, vb.end, vb.claimed, claimable);
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "VestedAkro: approve from the zero address");
        require(spender != address(0), "VestedAkro: approve to the zero address");

        allowances[owner][spender] = amount;
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
        emit Locked(holder, amount);
    }

    function claimAllFromBatches(address holder) internal {
        claimAllFromBatches(holder, holders[holder].batches.length);
    }

    function claimAllFromBatches(address holder, uint256 tillBatch) internal {
        Balance storage b = holders[holder];
        bool firstUnclaimedFound;
        uint256 claiming;
        for(uint256 i = b.firstUnclaimedBatch; i < tillBatch; i++) {
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
        if(!firstUnclaimedFound) {
            b.firstUnclaimedBatch = b.batches.length;
        }
        if(claiming > 0){
            b.locked = b.locked.sub(claiming);
            b.unlocked = b.unlocked.add(claiming);
            emit Unlocked(holder, claiming);
        }
    }

    /**
     * @notice Calculates claimable amount from all batches
     * @param holder pointer to a batch
     * @return claimable amount
     */
    function calculateClaimableFromBatches(address holder) internal view returns(uint256) {
        Balance storage b = holders[holder];
        uint256 claiming;
        for(uint256 i = b.firstUnclaimedBatch; i < b.batches.length; i++) {
            (uint256 claimable,) = calculateClaimableFromBatch(b.batches[i]);
            claiming = claiming.add(claimable);
        }
        return claiming;
    }

    /**
     * @notice Calculates one batch
     * @param vb pointer to a batch
     * @return claimable amount and bool which is true if batch is fully claimable
     */
    function calculateClaimableFromBatch(VestedBatch storage vb) internal view returns(uint256, bool) {
        //if(now < vb.start) return (0, false); // this should never happen because we have no cliff period
        if(now >= vb.end) {
            return (vb.amount.sub(vb.claimed), true);
        }
        uint256 claimable = (vb.amount.mul(now.sub(vb.start)).div(vb.end.sub(vb.start))).sub(vb.claimed);
        return (claimable, false);
    }
}