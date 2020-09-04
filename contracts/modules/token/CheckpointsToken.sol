pragma solidity ^0.5.12;

import "../../common/Base.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/lifecycle/Pausable.sol";

contract CheckpointsToken is Base, Pausable {
    
    // The block number that the Clone Token was created
    uint128 public creationBlock;

    // Token address that was cloned to produce this token;
    // 0x0 for a token that was not cloned
    address public parentToken;

    // Block number from the Parent Token that was
    // used to determine the initial distribution of the Clone Token
    uint public parentSnapShotBlock;
    
    /**
     * @dev `Checkpoint` is the structure that attaches a block number to a
     *  given value, the block number attached is the one that last changed the value
     */
    struct Checkpoint {
        uint fromBlock;
        uint256 value;
    }

    mapping (address => Checkpoint[]) private _balances;

    // Tracks the history of the `totalSupply` of the token
    Checkpoint[] totalSupplyHistory;

    function initialize(
        address _parentToken,
        uint _parentSnapShotBlock,
        bool _paused
    ) public initializer
    {
        Base.initialize();
        Pausable.initialize(_msgSender());
        if (_paused)
        {
            pause();
        }
        parentToken = _parentToken;
        parentSnapShotBlock = _parentSnapShotBlock;

    }

    function totalSupplyAt(uint _blockNumber) public view returns(uint256) {

        // These next few lines are used when the totalSupply of the token is
        //  requested before a check point was ever created for this token, it
        //  requires that the `parentToken.totalSupplyAt` be queried at the
        //  genesis block for this token as that contains totalSupply of this
        //  token at this block number.
        if ((totalSupplyHistory.length == 0) || (totalSupplyHistory[0].fromBlock > _blockNumber)) {
            if (address(parentToken) != address(0)) {
                return CheckpointsToken(parentToken).totalSupplyAt(min(_blockNumber, parentSnapShotBlock));
            } else {
                return 0;
            }

        // This will return the expected totalSupply during normal situations
        } else {
            return getValueAt(totalSupplyHistory, _blockNumber);
        }
    }

    function balanceOfAt(address _account, uint _blockNumber) public view returns (uint256) {

        // These next few lines are used when the balance of the token is
        //  requested before a check point was ever created for this token, it
        //  requires that the `parentToken.balanceOfAt` be queried at the
        //  genesis block for that token as this contains initial balance of
        //  this token
        if ((_balances[_account].length == 0) || (_balances[_account][0].fromBlock > _blockNumber)) {
            if (address(parentToken) != address(0)) {
                return CheckpointsToken(parentToken).balanceOfAt(_account, min(_blockNumber, parentSnapShotBlock));
            } else {
                // Has no parent
                return 0;
            }

        // This will return the expected balance during normal situations
        } else {
            return getValueAt(_balances[_account], _blockNumber);
        }
    }

    function getValueAt(Checkpoint[] storage checkpoints, uint _block) view internal returns (uint256) {
        if (checkpoints.length == 0)
            return 0;

        // Shortcut for the actual value
        if (_block >= checkpoints[checkpoints.length-1].fromBlock)
            return checkpoints[checkpoints.length-1].value;
        if (_block < checkpoints[0].fromBlock)
            return 0;

        // Binary search of the value in the array
        uint min = 0;
        uint max = checkpoints.length-1;
        while (max > min) {
            uint mid = (max + min + 1) / 2;
            if (checkpoints[mid].fromBlock<=_block) {
                min = mid;
            } else {
                max = mid-1;
            }
        }
        return checkpoints[min].value;
    }

    function updateValueAtAddressNow(address _account, uint256 _amount) internal {
        updateValueAtNow(_balances[_account], _amount);
    }

    function updateValueSupplyNow(uint256 _amount) internal {
        updateValueAtNow(totalSupplyHistory, _amount);
    }

    function updateValueAtNow(Checkpoint[] storage checkpoints, uint256 _value) internal {
        if ((checkpoints.length == 0) || (checkpoints[checkpoints.length - 1].fromBlock < block.number)) {
            Checkpoint storage newCheckPoint = checkpoints[checkpoints.length++];
            newCheckPoint.fromBlock = uint128(block.number);
            newCheckPoint.value = _value;
        } else {
            Checkpoint storage oldCheckPoint = checkpoints[checkpoints.length - 1];
            oldCheckPoint.value = _value;
        }
    }

    function min(uint a, uint b) pure private returns (uint) {
        return a < b ? a : b;
    }
}