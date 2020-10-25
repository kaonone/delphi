pragma solidity ^0.5.12;

import "./PoolToken.sol";
import "../../interfaces/token/IOperableToken.sol";

contract VaultPoolToken is PoolToken, IOperableToken {

    uint256 internal toBeMinted;

    mapping(address => uint256) internal onHoldAmount;
    uint256 totalOnHold;

    function _mint(address account, uint256 amount) internal {
        _createDistributionIfReady();
        toBeMinted = amount;
        _updateUserBalance(account);
        toBeMinted = 0;
        ERC20._mint(account, amount);
        userBalanceChanged(account);
    }

    function increaseOnHoldValue(address _user, uint256 _amount) public onlyMinter {
        onHoldAmount[_user] = onHoldAmount[_user].add(_amount);
        totalOnHold = totalOnHold.add(_amount);
    }

    function decreaseOnHoldValue(address _user, uint256 _amount) public onlyMinter {
        if (onHoldAmount[_user] >= _amount) {
            _updateUserBalance(_user);

            onHoldAmount[_user] = onHoldAmount[_user].sub(_amount);
            if (distributions.length > 0 && nextDistributions[_user] < distributions.length) {
                nextDistributions[_user] = distributions.length;
            }
            totalOnHold = totalOnHold.sub(_amount);

            userBalanceChanged(_user);
        }
    }

    function onHoldBalanceOf(address _user) public view returns (uint256) {
        return onHoldAmount[_user];
    }


    function fullBalanceOf(address account) public view returns(uint256){
        if (account == address(this)) return 0;  //Token itself only holds tokens for others
        uint256 unclaimed = calculateClaimAmount(account);
        return balanceOf(account).add(unclaimed);
    }

    function distributionBalanceOf(address account) public view returns(uint256) {
        if (balanceOf(account).add(toBeMinted) <= onHoldAmount[account])
            return 0;
        return balanceOf(account).add(toBeMinted).sub(onHoldAmount[account]);
    }

    function distributionTotalSupply() public view returns(uint256){
        return totalSupply().sub(totalOnHold);
    }

    function userBalanceChanged(address account) internal {
        //Disable rewards for the vaults
    }
}