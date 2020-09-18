pragma solidity ^0.5.12;

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";

import "../../interfaces/defi/IVaultProtocol.sol";
import "../../common/Module.sol";
import "./DefiOperatorRole.sol";

contract VaultProtocol is Module, IVaultProtocol, DefiOperatorRole {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct DepositData {
        address depositedToken;
        uint256 depositedAmount;
    }

    //deposits waiting for the defi operator's actions
    mapping(address => DepositData[]) internal balancesOnHold;
    address[] internal usersDeposited; //for operator's conveniency

    //Withdraw requests waiting for the defi operator's actions
    mapping(address => DepositData[]) internal balancesRequested;
    address[] internal usersRequested; //for operator's conveniency


    function initialize(address _pool) public initializer {
        Module.initialize(_pool);
        DefiOperatorRole.initialize(_msgSender());
    }



//IVaultProtocol methods
    function depositToVault(address _user, address _token, uint256 _amount) public onlyDefiOperator {
        require(_user != address(0), "Incorrect user address");
        require(_token != address(0), "Incorrect token address");
        require(_amount > 0, "No tokens to be deposited");

        IERC20(_token).transferFrom(_user, address(this), _amount);

        uint256 ind;
        bool hasToken;
        (hasToken, ind) = hasOnHoldToken(_user, _token);

        if (hasToken) {
            balancesOnHold[_user][ind].depositedAmount = balancesOnHold[_user][ind].depositedAmount.add(_amount);
        }
        else {
            balancesOnHold[_user].push( DepositData({
                depositedToken: _token,
                depositedAmount: _amount
            }) );
            usersDeposited.push(_user);
        }

        emit DepositToVault(_user, _token, _amount);
    }

    function depositToVault(address _user, address[] memory  _tokens, uint256[] memory _amounts) public onlyDefiOperator {
        require(_tokens.length > 0, "No tokens to be deposited");
        require(_tokens.length == _amounts.length, "Incorrect amounts");

        for (uint256 i = 0; i < _tokens.length; i++) {
            depositToVault(_user, _tokens[i], _amounts[i]);
        }
    }

    function withdrawFromVault(address _user, address _token, uint256 _amount) public onlyDefiOperator {
        require(_user != address(0), "Incorrect user address");
        require(_token != address(0), "Incorrect token address");
        require(_amount > 0, "No tokens to be withdrawn");

        if (IERC20(_token).balanceOf(address(this)) >= _amount) {
            IERC20(_token).transfer(_user, _amount);

            emit WithdrawFromVault(_user, _token, _amount);

            updateOnHoldDeposit(_user, _token, _amount);
        }
        else {
            uint256 ind;
            bool hasRequest;
            (hasRequest, ind) = hasRequestedToken(_user, _token);

            if (hasRequest) {
                balancesRequested[_user][ind].depositedAmount = balancesRequested[_user][ind].depositedAmount.add(_amount);
            }
            else {
                balancesRequested[_user].push( DepositData({
                    depositedToken: _token,
                    depositedAmount: _amount
                }) );
                usersRequested.push(_user);
            }

            emit WithdrawRequestCreated(_user, _token, _amount);
        }
    }

    function withdrawFromVault(address _user, address[] memory  _tokens, uint256[] memory _amounts) public onlyDefiOperator {
        require(_tokens.length > 0, "No tokens to be withdrawn");
        require(_tokens.length == _amounts.length, "Incorrect amounts");

        for (uint256 i = 0; i < _tokens.length; i++) {
            withdrawFromVault(_user, _tokens[i], _amounts[i]);
        }
    }

    function quickWithdraw(address _user, uint256 _amount) public {
        //stab
        //available for any how pays for all the gas and is allowed to withdraw
        //should be overloaded in the protocol adapter itself
    }

    function canWithdrawFromVault(address _user, uint256 _amount) public view returns (bool) {
        //stab
        //check if the vault has liquidity
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

    function hasOnHoldToken(address _user, address _token) internal view returns (bool, uint256) {
        uint256 ind = 0;
        bool hasToken = false;
        for (uint i = 0; i < balancesOnHold[_user].length; i++) {
            if (balancesOnHold[_user][i].depositedToken == _token) {
                ind = i;
                hasToken = true;
                break;
            }
        }
        return (hasToken, ind);
    }

    function amountOnHold(address _user, address _token) public view returns (uint256) {
        uint256 amount = 0;
        for (uint i = 0; i < balancesOnHold[_user].length; i++) {
            if (balancesOnHold[_user][i].depositedToken == _token) {
                amount = balancesOnHold[_user][i].depositedAmount;
                break;
            }
        }
        return amount;
    }

    function updateOnHoldDeposit(address _user, address _token, uint256 _amount) internal {
        uint256 ind;
        bool hasToken;
        (hasToken, ind) = hasOnHoldToken(_user, _token);

        if (hasToken) {
            uint256 onHoldBalance = balancesOnHold[_user][ind].depositedAmount;
            if (onHoldBalance > _amount) {
                balancesOnHold[_user][ind].depositedAmount = onHoldBalance.sub(_amount);
            }
            else {
                if (balancesOnHold[_user].length == 1) {
                    delete balancesOnHold[_user];
                }
                else {
                    //Will be deleted by operator on resolving on-hold deposites
                    balancesOnHold[_user][ind].depositedAmount = 0;
                }
            }
        }
    }

    function hasRequestedToken(address _user, address _token) internal view returns (bool, uint256) {
        uint256 ind = 0;
        bool hasToken = false;
        for (uint i = 0; i < balancesRequested[_user].length; i++) {
            if (balancesRequested[_user][i].depositedToken == _token) {
                ind = i;
                hasToken = true;
                break;
            }
        }
        return (hasToken, ind);
    }

    function amountRequested(address _user, address _token) public view returns (uint256) {
        uint256 amount = 0;
        for (uint i = 0; i < balancesRequested[_user].length; i++) {
            if (balancesRequested[_user][i].depositedToken == _token) {
                amount = balancesRequested[_user][i].depositedAmount;
                break;
            }
        }
        return amount;
    }

//IDefiProtocol methods
    function handleDeposit(address token, uint256 amount) public onlyDefiOperator {
        // will be overloaded in adapter and use the steps from the strategy
    }

    function handleDeposit(address[] memory tokens, uint256[] memory amounts) public onlyDefiOperator {
        //the same but in cycle
    }
    function withdraw(address beneficiary, address token, uint256 amount) public {
        // will be overloaded in adapter and use the withdraw steps from the strategy
    }

    function withdraw(address beneficiary, uint256[] memory amounts) public {
        //the same but in cycle
    }
    function claimRewards() public returns(address[] memory tokens, uint256[] memory amounts) {
        tokens = new address[](1);
        amounts = new uint256[](1);
    }

    function withdrawReward(address token, address user, uint256 amount) public {

    }


    function balanceOf(address token) public returns(uint256) {
        return 0;
    }

    function balanceOfAll() external returns(uint256[] memory) {
        uint256[] memory a = new uint256[](1);
        return a;
    }

    function optimalProportions() external returns(uint256[] memory) {
                uint256[] memory a = new uint256[](1);
        return a;
    }

    function normalizedBalance() external returns(uint256) {
        return 0;
    }

    function supportedTokens() external view returns(address[] memory) {
        address[] memory a = new address[](1);
        return a;
    }

    function supportedTokensCount() external view returns(uint256) {
        return 0;
    }

    function supportedRewardTokens() external view returns(address[] memory) {
        address[] memory a = new address[](1);
        return a;
    }

    function isSupportedRewardToken(address token) external view returns(bool) {
        return false;
    }

    function canSwapToToken(address token) external view returns(bool) {
        return false;
    }

}