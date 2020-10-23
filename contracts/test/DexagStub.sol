pragma solidity ^0.5.12;

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/SafeERC20.sol";

import "../interfaces/defi/IDexag.sol";

contract IWETH is IERC20 {
    function withdraw(uint256 amount) external;
}

contract ApprovalHandlerStub {
    using SafeERC20 for IERC20;

    function transferFrom(IERC20 erc, address sender, address receiver, uint256 numTokens) external {
        erc.safeTransferFrom(sender, receiver, numTokens);
    }
}

contract DexagStub is IDexag {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    ApprovalHandlerStub public _approvalHandler;

    event Trade(address indexed from, address indexed to, uint256 toAmount, address indexed trader, address[] exchanges, uint256 tradeType);

    address public WETH;

    constructor() public {
        _approvalHandler = new ApprovalHandlerStub();
    }

    function setProtocol(address _weth) public {
        WETH = _weth;
    }

    function trade(
        address from,
        address to,
        uint256 fromAmount,
        address[] memory exchanges,
        address[] memory approvals,
        bytes memory data,
        uint256[] memory offsets,
        uint256[] memory etherValues,
        uint256 limitAmount,
        uint256 tradeType
    ) public payable {
        require(exchanges.length > 0, "No Exchanges");
        require(exchanges.length == approvals.length, "Every exchange must have an approval set");
        require(limitAmount > 0, "Limit Amount must be set");

        // if from is an ERC20, pull tokens from msg.sender
        if (from != address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)) {
            require(msg.value == 0);
            _approvalHandler.transferFrom(IERC20(from), msg.sender, address(this), fromAmount);
        }

        // execute trades on dexes
        executeTrades(IERC20(from), exchanges, approvals, data, offsets, etherValues);

        // check how many tokens were received after trade execution
        uint256 tradeReturn = viewBalance(IERC20(to), address(this));
        require(tradeReturn >= limitAmount, "Trade returned less than the minimum amount");

        // return any unspent funds
        uint256 leftover = viewBalance(IERC20(from), address(this));
        if (leftover > 0) {
            sendFunds(IERC20(from), msg.sender, leftover);
        }

        sendFunds(IERC20(to), msg.sender, tradeReturn);

        emit Trade(from, to, tradeReturn, msg.sender, exchanges, tradeType);
    }

    function executeTrades(
        IERC20 from,
        address[] memory exchanges,
        address[] memory approvals,
        bytes memory data,
        uint256[] memory offsets,
        uint256[] memory etherValues) internal {
            for (uint i = 0; i < exchanges.length; i++) {
                // prevent calling the approvalHandler and check that exchange is a valid contract address
                require(exchanges[i] != address(_approvalHandler), "Invalid Address");
                if (approvals[i] != address(0)) {
                    // handle approval if the aprovee is not the exchange address
                    approve(from, approvals[i]);
                } else {
                    // handle approval if the approvee is the exchange address
                    approve(from, exchanges[i]);
                }
                // do trade
                require(external_call(exchanges[i], etherValues[i], offsets[i], offsets[i + 1] - offsets[i], data), "External Call Failed");
            }
        }

    // ERC20 Utility Functions

    function approve(IERC20 erc, address approvee) internal {
        if (
            address(erc) != 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE &&
            erc.allowance(address(this), approvee) == 0
        ) {
            erc.safeApprove(approvee, uint256(-1));
        }
    }

    function viewBalance(IERC20 erc, address owner) internal view returns(uint256) {
        if (address(erc) == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) {
            return owner.balance;
        } else {
            return erc.balanceOf(owner);
        }
    }

    function sendFunds(IERC20 erc, address payable receiver, uint256 funds) internal {
        if (address(erc) == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) {
            receiver.transfer(funds);
        } else {
            erc.safeTransfer(receiver, funds);
        }
    }

    // Source: https://github.com/gnosis/MultiSigWallet/blob/master/contracts/MultiSigWallet.sol
    // call has been separated into its own function in order to take advantage
    // of the Solidity's code generator to produce a loop that copies tx.data into memory.
    function external_call(address destination, uint value, uint dataOffset, uint dataLength, bytes memory data) internal returns (bool) {
        bool result;
        assembly {
            let x := mload(0x40)   // "Allocate" memory for output (0x40 is where "free memory" pointer is stored by convention)
            let d := add(data, 32) // First 32 bytes are the padded length of data, so exclude that
            result := call(
                sub(gas, 34710),   // 34710 is the value that solidity is currently emitting
                                   // It includes callGas (700) + callVeryLow (3, to pay for SUB) + callValueTransferGas (9000) +
                                   // callNewAccountGas (25000, in case the destination address does not exist and needs creating)
                destination,
                value,
                add(d, dataOffset),
                dataLength,        // Size of the input (in bytes) - this is what fixes the padding problem
                x,
                0                  // Output is ignored, therefore the output size is zero
            )
        }
        return result;
    }

    function withdrawWeth() external {
        uint256 amount = IERC20(WETH).balanceOf(address(this));
        IWETH(WETH).withdraw(amount);
    }

    function () external payable {
        require(msg.sender != tx.origin);
    }

    function approvalHandler() external returns(address) {
        return address(_approvalHandler);
    }
}