pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

import "../../common/Base.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/SafeERC20.sol";

contract Structs {
    struct Val {
        uint256 value;
    }

    enum ActionType {
        Deposit,   // supply tokens
        Withdraw  // borrow tokens
    }

    enum AssetDenomination {
        Wei // the amount is denominated in wei
    }

    enum AssetReference {
        Delta // the amount is given as a delta from the current value
    }

    struct AssetAmount {
        bool sign; // true if positive
        AssetDenomination denomination;
        AssetReference ref;
        uint256 value;
    }

    struct ActionArgs {
        ActionType actionType;
        uint256 accountId;
        AssetAmount amount;
        uint256 primaryMarketId;
        uint256 secondaryMarketId;
        address otherAddress;
        uint256 otherAccountId;
        bytes data;
    }

    struct Info {
        address owner;  // The address that owns the account
        uint256 number; // A nonce that allows a single address to control many accounts
    }

    struct Wei {
        bool sign; // true if positive
        uint256 value;
    }
}

contract DyDxStub is Structs {
    function getAccountWei(Info memory account, uint256 marketId) public view returns (Wei memory) {
        return Wei({
            sign: true,
            value: 0
        });
    }
    function operate(Info[] memory accounts, ActionArgs[] memory args) public {
        require(accounts.length == args.length, "Array size mismatch");
        for(uint256 i=0; i< accounts.length; i++) {
            _operate(accounts[i], args[i]);
        }
    }

    function _operate(Info memory account, ActionArgs memory arg) internal {
        address beneficiary = account.owner;
        if(arg.actionType == ActionType.Deposit) {
            _deposit(beneficiary);
        } else if(arg.actionType == ActionType.Deposit) {
            _withdraw(beneficiary);
        } else {
            revert("Unsupported action");
        }
    }

    function _deposit(address beneficiary) internal {
    }

    function _withdraw(address beneficiary) internal {
    }
}
