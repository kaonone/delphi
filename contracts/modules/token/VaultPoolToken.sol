pragma solidity ^0.5.12;

import "./PoolToken.sol";
import "../../interfaces/token/IOperableToken.sol";

contract VaultPoolToken is PoolToken, IOperableToken {

    mapping(address => uint256) internal onHoldAmount;
    uint256 totalOnHold;

    function increaseOnHoldValue(address _user, uint256 _amount) public onlyMinter {
        onHoldAmount[_user] = onHoldAmount[_user].add(_amount);
        totalOnHold = totalOnHold.add(_amount);
    }

    function decreaseOnHoldValue(address _user, uint256 _amount) public onlyMinter {
        if (onHoldAmount[_user] >= _amount) {
            onHoldAmount[_user] = onHoldAmount[_user].sub(_amount);
            if (distributions.length > 0 && nextDistributions[_user] < distributions.length) {
                nextDistributions[_user] = distributions.length;
            }
            totalOnHold = totalOnHold.sub(_amount);
        }
    }

    function onHoldBalanceOf(address _user) public view returns (uint256) {
        return onHoldAmount[_user];
    }


    function fullBalanceOf(address account) public view returns(uint256){
        if (account == address(this)) return 0;  //Token itself only holds tokens for others
        uint256 distributionBalance = distributionBalanceOf(account);
        uint256 unclaimed = calculateClaimAmount(account);
        return distributionBalance.add(unclaimed).add(onHoldBalanceOf(account));
    }

    function distributionBalanceOf(address account) public view returns(uint256) {
        return balanceOf(account).add(toBeMinted).sub(onHoldAmount[account]);
    }

    function distributionTotalSupply() public view returns(uint256){
        return totalSupply().sub(totalOnHold);
    }
}