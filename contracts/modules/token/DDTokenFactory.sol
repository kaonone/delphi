pragma solidity ^0.5.12;

import "../../common/Base.sol";
import "./DDToken.sol";

contract DDTokenFactory is Base {

    function initialize() public initializer {
        Base.initialize();
    }
    event NewFactoryCloneToken(address indexed _cloneToken, address indexed _parentToken, uint _snapshotBlock);

    /// @notice Update the DApp by creating a new token with new functionalities
    ///  the msg.sender becomes the controller of this clone token
    /// @param _parentToken Address of the token being cloned
    /// @param _snapshotBlock Block of the parent token that will
    ///  determine the initial distribution of the clone token
    /// @param _tokenName Name of the new token
    /// @param _decimalUnits Number of decimals of the new token
    /// @param _tokenSymbol Token Symbol for the new token
    /// @param _transfersEnabled If true, tokens will be able to be transferred
    /// @return The address of the new token contract
    function createCloneToken(
        DDToken _parentToken,
        uint _snapshotBlock,
        string memory _tokenName,
        uint8 _decimalUnits,
        string memory _tokenSymbol,
        bool _transfersEnabled
    ) public returns (DDToken)
    {
        DDToken newToken = new DDToken();

        newToken.initialize(
            this,
            _parentToken,
            _snapshotBlock,
            _tokenName,
            _decimalUnits,
            _tokenSymbol,
            _transfersEnabled
        );

        newToken.transferOwnership(msg.sender);
        emit NewFactoryCloneToken(address(newToken), address(_parentToken), _snapshotBlock);
        return newToken;
    }
}