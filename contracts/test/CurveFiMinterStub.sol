pragma solidity ^0.5.12;

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Mintable.sol";

import "../interfaces/defi/ICurveFiMinter.sol";
import "../interfaces/defi/ICurveFiLiquidityGauge.sol";


contract CurveFiMinterStub is ICurveFiMinter {
    mapping(address => mapping(address => uint256)) public minted_for;
    mapping(address => mapping(address => bool)) public allowed_to_mint_for;
    address public token;

    function initialize(address _crvToken) public {
        token = _crvToken;
    }

    /**
     *  @notice Mint everything which belongs to 'msg.sender' and send to them
     *  @param gauge_addr `LiquidityGauge` address to get mintable amount from
     */
    function mint(address gauge_addr) public {
        _mint_for(gauge_addr, msg.sender);
    }

    /**
     * @notice Mint everything which belongs to 'msg.sender' across multiple gauges
     * @param gauge_addrs List of 'LiquidityGauge' addresses
     */
    function mint_many(address[8] memory gauge_addrs) public {
        for (uint256 i = 0; i < 8; i++) {
            if (gauge_addrs[i] == address(0))
                break;
            _mint_for(gauge_addrs[i], msg.sender);
        }
    }

    /**
     * @notice Mint tokens for `_for`
     * @dev Only possible when `msg.sender` has been approved via 'toggle_approve_mint'
     * @param gauge_addr `LiquidityGauge` address to get mintable amount from
     *@param _for Address to mint to
     */
    function mint_for(address gauge_addr, address _for) public {
        //if (allowed_to_mint_for[msg.sender][_for])
        _mint_for(gauge_addr, _for);
    }

    function minted(address _for, address gauge_addr) public returns(uint256) {
        return minted_for[_for][gauge_addr];
    }

    /**
     * @notice allow `minting_user` to mint for `msg.sender`
     * @param minting_user Address to toggle permission for
     */
    function toggle_approve_mint(address minting_user) public {
        allowed_to_mint_for[minting_user][msg.sender] = !allowed_to_mint_for[minting_user][msg.sender];
    }

    function _mint_for(address gauge_addr, address _for) internal {
        ICurveFiLiquidityGauge(gauge_addr).user_checkpoint(_for);
        uint256 total_mint = ICurveFiLiquidityGauge(gauge_addr).integrate_fraction(_for);
        uint256 to_mint = total_mint - minted_for[_for][gauge_addr];

        if (to_mint != 0) {
            ERC20Mintable(token).mint(_for, to_mint);
            minted_for[_for][gauge_addr] = total_mint;
        }
    }
}