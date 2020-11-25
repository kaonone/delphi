pragma solidity ^0.5.0;
//pragma experimental ABIEncoderV2;

contract CallExecutor {
    struct Call {
        address payable target;
        bytes callData;
        uint256 value;
    }

    Call[] public calls;

    function clearCalls() external {
        delete calls;
    }

    function addCall(address payable target, bytes calldata callData, uint256 value) external {
        calls.push(Call({
            target: target,
            callData: callData,
            value: value
        }));
    }

    function setCall(uint256 idx, address payable target, bytes calldata callData, uint256 value) external {
        require(idx < calls.length, "Array index too high");
        calls[idx].target = target;
        calls[idx].callData = callData;
        calls[idx].value = value;
    }

    function execute() external payable{
        for(uint256 i=0; i<calls.length; i++) {
            address payable target = calls[i].target;
            bytes memory callData = calls[i].callData;
            uint256 val = calls[i].value;
            (bool success, bytes memory result) = target.call.value(val)(callData);
            if(!success) assembly {
                revert(add(result,32), result) //return original revert reason
            }
        }
    }
}