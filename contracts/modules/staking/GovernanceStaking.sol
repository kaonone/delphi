pragma solidity ^0.5.12;

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";

import "./StakingPool.sol";
import "../../common/Module.sol";
import "../token/ADEL.sol";
import "../token/DDToken.sol";

/**
 * @dev Contract for governance staking. Contains the proportion of AKRO and ADEL tokens for staking.
 * @dev Mints Delphi DAO tokens instead of staked sum of AKRO and ADEL tokens
 */
contract GovernanceStaking is StakingPool {
    using SafeMath for uint256;
    
    uint256 constant public PRECISION = 100;
    uint256 public akroProportion;
    
    //stakingToken from StakingPool contract is used for AKRO token
    ADEL adelToken;
    DDToken ddToken;
    
    
    function initialize(address _pool, ERC20 _akroToken, ADEL _adelToken, DDToken _ddToken,
                        uint256 _defaultLockInDuration, uint256 _akroProportion ) public initializer
    {
        require(_akroProportion != 0, "Incorrect proportion");
        require(_akroProportion < PRECISION, "Incorrect proportion");

        akroProportion = _akroProportion;
        adelToken = _adelToken;
        ddToken = _ddToken;
        StakingPool.initialize(_pool, _akroToken, _defaultLockInDuration);
    }

    /**
    * @dev Overrides the behavior from the StakingPool contract.
    * @dev Performs transfers of AKRO and ADEL tokens in proportion of the pool.
    * @dev Performs minting of the Delphi DAO tokens.
    * @param _address address to transfer tokens from
    * @param _amount uint256 the number of DDT tokens to be minted
    */
    function resolveStakingTokens(address _address, uint256 _amount) internal returns(uint256)
    {
        uint256 akroAmount = _amount.mul(akroProportion).div(PRECISION);
        uint256 adelAmount = _amount.mul(PRECISION.sub(akroProportion)).div(PRECISION);
        uint256 actualAmount = akroAmount.add(adelAmount);

        require(akroAmount != 0, "Unsufficient AKRO stake");
        require(adelAmount != 0, "Unsufficient ADEL stake");

        require(stakingToken.transferFrom(_address, address(this), akroAmount), "AKRO stake required");
        require(adelToken.transferFrom(_address, address(this), adelAmount), "ADEL stake required");
        
        ddToken.mint(_address, actualAmount);

        return actualAmount;
    }

    /**
    * @dev Overrides the behavior from the StakingPool contract.
    * @dev Function transfers staked tokens from this contract back to the sender
    * @param _address address to transfer tokens
    * @param _amount uint256 the number of tokens
    */
    function resolveUnstakingTokens(address _address, uint256 _amount) internal {
        // StakingPool contract uses this function to withdraw all the tokens
        // so we can use simplified calculation
        uint256 akroAmount = _amount.mul(akroProportion).div(PRECISION);
        uint256 adelAmount = _amount.sub(akroAmount);
        require(stakingToken.transfer(_address, akroAmount), "Unable to withdraw AKRO stake");
        require(adelToken.transfer(_address, adelAmount), "Unable to withdraw ADEL stake");

        //Return and burn minted DDT tokens
        require(ddToken.transferFrom(_address, address(this), _amount), "DDT transfer required");
        ddToken.burn(_amount);
    }

}