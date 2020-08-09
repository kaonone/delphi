pragma solidity ^0.5.12;

interface IAccessModule {
    enum Operation {
        Deposit,
        Withdraw
    }
    
    /**
     * @notice Check if operation is allowed
     * @param operation Requested operation
     * @param sender Sender of transaction
     */
    function isOperationAllowed(Operation operation, address sender) external view returns(bool);
}