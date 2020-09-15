pragma solidity ^0.5.12;

import "../../interfaces/defi/IVaultProtocol.sol";
import "../../common/Module.sol";
import "./DefiOperatorRole.sol";

contract VaultProtocol is Module, IVaultProtocol, DefiOperatorRole {

//IVaultProtocol methods

    function quickWithdraw(address _user, uint256 _amount) public {
        //stab
        //available for any how pays for all the gas and is allowed to withdraw
    }

    function canWithdrawFromVault(address _user, uint256 _amount) public view returns (bool) {
        //stab
        return true;
    }

    function requestWithdraw(address _user, uint256 _amount) public {
        //stab
        //function to create withdraw request
    }

    function getRequested() public view onlyDefiOperator returns (uint256) {
        //stab
        //returns the amount of requested tokens
        return 0;
    }

    function claimRequested(address _user, uint256 _amount) public {
        //stab
        //available for the user with fullfilled request
    }

    function canClaimRequested(address _user, uint256 _amount) public view returns (bool) {
        //stab
        //view function for the user
        return true;
    }

    function withdrawOperator(uint256 _amount) public onlyDefiOperator {
        //stab
        //method for the operator. Works with actual withdraw from the protocol
    }

    function depositOperator(uint256 _amount) public onlyDefiOperator {
        //stab
        //method for the operator. Works with actual deposit to the protocol/strategy
    }

//IDefiProtocol methods

}