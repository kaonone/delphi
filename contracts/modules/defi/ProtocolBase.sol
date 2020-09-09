pragma solidity ^0.5.12;

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "../../interfaces/defi/IDefiProtocol.sol";
import "../../interfaces/defi/ICErc20.sol";
import "../../interfaces/defi/IComptroller.sol";
import "../../common/Module.sol";
import "../reward/RewardVestingModule.sol";
import "./DefiOperatorRole.sol";

contract ProtocolBase is Module, DefiOperatorRole, IDefiProtocol {
    uint256 constant MAX_UINT256 = uint256(-1);

    event RewardTokenClaimed(address indexed token, uint256 amount);

    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    mapping(address=>uint256) public rewardBalances;    //Mapping of already claimed amounts of reward tokens

    function initialize(address _pool) public initializer {
        Module.initialize(_pool);
        DefiOperatorRole.initialize(_msgSender());
    }

    function supportedRewardTokens() public view returns(address[] memory) {
        return defaultRewardTokens();
    }

    function isSupportedRewardToken(address token) public view returns(bool) {
        address[] memory srt = supportedRewardTokens();
        for(uint256 i=0; i < srt.length; i++) {
            if(srt[i] == token) return true;
        }
        return false;
    }

    function cliamRewardsFromProtocol() internal;

    function claimRewards() public onlyDefiOperator returns(address[] memory tokens, uint256[] memory amounts){
        cliamRewardsFromProtocol();
        claimDefaultRewards();

        // Check what we received
        address[] memory rewardTokens = supportedRewardTokens();
        uint256[] memory rewardAmounts = new uint256[](rewardTokens.length);
        uint256 receivedRewardTokensCount;
        for(uint256 i = 0; i < rewardTokens.length; i++) {
            address rtkn = rewardTokens[i];
            uint256 newBalance = IERC20(rtkn).balanceOf(address(this));
            if(newBalance > rewardBalances[rtkn]) {
                receivedRewardTokensCount++;
                rewardAmounts[i] = newBalance.sub(rewardBalances[rtkn]);
                rewardBalances[rtkn] = newBalance;
            }
        }

        //Fill result arrays
        tokens = new address[](receivedRewardTokensCount);
        amounts = new uint256[](receivedRewardTokensCount);
        if(receivedRewardTokensCount > 0) {
            uint256 j;
            for(uint256 i = 0; i < rewardTokens.length; i++) {
                if(rewardAmounts[i] > 0) {
                    tokens[j] = rewardTokens[i];
                    amounts[j] = rewardAmounts[i];
                    j++;
                }
            }
        }
    }

    function withdrawReward(address token, address user, uint256 amount) public onlyDefiOperator {
        require(isSupportedRewardToken(token), "ProtocolBase: not reward token");
        rewardBalances[token] = rewardBalances[token].sub(amount);
        IERC20(token).safeTransfer(user, amount);
    }

    function claimDefaultRewards() internal {
        RewardVestingModule rv = RewardVestingModule(getModuleAddress(MODULE_REWARD));
        rv.claimRewards();
    }

    function defaultRewardTokens() internal view returns(address[] memory) {
        address[] memory rt = new address[](2);
        return defaultRewardTokensFillArray(rt);
    }
    function defaultRewardTokensFillArray(address[] memory rt) internal view returns(address[] memory) {
        require(rt.length >= 2, "ProtocolBase: not enough space in array");
        rt[0] = getModuleAddress(TOKEN_AKRO);
        rt[1] = getModuleAddress(TOKEN_ADEL);
        return rt;
    }
    function defaultRewardTokensCount() internal pure returns(uint256) {
        return 2;
    }
}
