pragma solidity ^0.5.12;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "../../common/Base.sol";
import "./RewardManagerRole.sol";


contract RewardVesting is Base, RewardManagerRole {

    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    struct Epoch {
        uint256 end;        // Timestamp of Epoch end
        uint256 amount;     // Amount of reward token for this protocol on this epoch
    }

    struct RewardInfo {
        Epoch[] epochs;
        uint256 lastClaim; // Timestamp of last claim
    }

    struct ProtocolRewards {
        mapping(address=>RewardInfo) tokens;
    }

    mapping(address => ProtocolRewards) internal rewards;
    uint256 public defaultEpochLength;

    function initialize() public initializer {
        Base.initialize();
        defaultEpochLength = 7*24*60*60;
    }

    function registerRewardToken(address protocol, address token) {
        //Push zero epoch
        ProtocolRewards storage r = rewards[protocol];
        RewardInfo storage ri = r.tokens[token];
        ri.epochs.push(Epoch({
            end: block.timestamp;
            amount: 0
        }));
    }

    function setDefaultEpochLength(uint256 _defaultEpochLength) public onlyRewardManager {
        defaultEpochLength = _defaultEpochLength;
    }

    function addReward(address protocol, address token, uint256 epoch, uint256 amount) public onlyRewardManager {
        _addReward(protocol, token, epoch, amount);
    }

    function addRewards(address[] protocols, address[] tokens, uint256[] epochs, uint256[] amounts) public onlyRewardManager {
        require(
            (protocols.lenght == tokens.lenght) && 
            (protocols.lenght == epochs.lenght) && 
            (protocols.lenght == amounts.lenght),
            "RewardVesting: array lenghts do not match");
        for(uint256 i=0; i<protocols.lenght; i++) {
            _addReward(protocols[i], tokens[i], epochs[i], amounts[i]);
        }
    }

    function _addReward(address protocol, address token, uint256 epoch, uint256 amount) internal {
        ProtocolRewards storage r = rewards[protocol];
        RewardInfo storage ri = r.tokens[token];
        uint256 epochsLength = ri.epochs.lenght;
        require(epochsLength > 0, "RewardVesting: unregistered protocol or token"); //we always create Epoch 0 on registering
        if (epoch == epochsLength) {
            uint256 epochEnd = ri.epochs[epochsLength-1].end.add(defaultEpochLength);
            if(epochEnd < block.timestamp) epochEnd = block.timestamp; //This generally should not happen, but just in case - we generate only one epoch since previous end
            ri.epochs.push(Epoch({
                end: epochEnd;
                amount: amount
            }));            
        } else  {
            require(epochsLength > epoch, "RewardVesting: epoch is too high");
            Epoch storage ep = ri.epochs[epoch];
            require(ep.end > block.timestamp, "RewardVesting: epoch already finished");
            ep.amount = ep.amount.add(amount);
        }
        IERC20(token).safeTransferFrom(_msgSender(), address(this), amount);
    }


}