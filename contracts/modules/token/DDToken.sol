pragma solidity ^0.5.12;

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/roles/MinterRole.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";

import "./CheckpointsToken.sol";
import "./DDTokenFactory.sol";

contract DDToken is ERC20Detailed, CheckpointsToken, MinterRole  {
    using SafeMath for uint256;

    event CloneToken(address indexed cloneToken, uint snapshotBlock);

    mapping (address => mapping (address => uint256)) private _allowances;

    DDTokenFactory public tokenFactory;

    function initialize(
        DDTokenFactory _tokenFactory,
        DDToken _parentToken,
        uint _parentSnapShotBlock,
        string memory _tokenName,
        uint8 _decimalUnits,
        string memory _tokenSymbol,
        bool _paused
    ) public initializer
    {
        ERC20Detailed.initialize(_tokenName, _tokenSymbol, _decimalUnits);
        CheckpointsToken.initialize(address(_parentToken), _parentSnapShotBlock, _paused);
        MinterRole.initialize(_msgSender());
        tokenFactory = _tokenFactory;
    }

    function transfer(address recipient, uint256 amount) public whenNotPaused returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public whenNotPaused returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        
        return true;
    }

    function approve(address spender, uint256 amount) public whenNotPaused returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function mint(address account, uint256 amount) public onlyMinter returns (bool) {
        _mint(account, amount);
        return true;
    }

    function burn(uint256 amount) public onlyMinter {
        _burn(_msgSender(), amount);
    }


    function cloneToken(
        string memory _cloneTokenName,
        uint8 _cloneDecimalUnits,
        string memory _cloneTokenSymbol,
        uint _snapshotBlock,
        bool _transfersEnabled
    ) public returns(DDToken)
    {
        uint snapshot = _snapshotBlock == 0 ? block.number - 1 : _snapshotBlock;

        DDToken clonedToken = tokenFactory.createCloneToken(
            this,
            snapshot,
            _cloneTokenName,
            _cloneDecimalUnits,
            _cloneTokenSymbol,
            _transfersEnabled
        );


        emit CloneToken(address(clonedToken), snapshot);
        return clonedToken;
    }


    function totalSupply() public view returns (uint256) {
        return totalSupplyAt(block.number);
    }

    function balanceOf(address account) public view returns (uint256) {
        return balanceOfAt(account, block.number);
    }

    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowances[owner][spender];
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(parentSnapShotBlock < block.number);
        require(sender != address(0), "Transfer from the zero address");
        require(recipient != address(0), "Transfer to the zero address");
        
        uint256 previousBalanceFrom = balanceOfAt(sender, block.number);
        updateValueAtAddressNow(sender, previousBalanceFrom.sub(amount, "Transfer amount exceeds balance"));

        uint256 previousBalanceTo = balanceOfAt(sender, block.number);
        updateValueAtAddressNow(recipient, previousBalanceTo.add(amount));

        emit Transfer(sender, recipient, amount);
    }

    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "Mint to the zero address");

        uint256 curTotalSupply = totalSupply();
        uint256 previousBalanceTo = balanceOf(account);

        updateValueSupplyNow(curTotalSupply.add(amount));
        updateValueAtAddressNow(account, previousBalanceTo.add(amount));
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: burn from the zero address");

        uint256 curTotalSupply = totalSupply();
        uint256 previousBalanceTo = balanceOf(account);

        updateValueSupplyNow(curTotalSupply.sub(amount));
        updateValueAtAddressNow(account, previousBalanceTo.sub(amount));
        emit Transfer(account, address(0), amount);
    }

}