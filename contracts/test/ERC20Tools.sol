pragma solidity ^0.5.0;

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";

interface Allocator {
    function allocateTo(address account, uint256 amount) external;
}

interface Mintable {
    function mint(address account, uint256 amount) external;
}


contract ERC20Tools {
    using SafeMath for uint256;
    
    function allocateTo(address account, address[] calldata tokens, uint256[] calldata amounts) external {
        require(tokens.length == amounts.length, "BulkERC20Actions: tokens/amounts length mismatch");
        for(uint256 i=0; i<tokens.length; i++) {
            Allocator(tokens[i]).allocateTo(account, amounts[i]);
        }
    }
    
    function allocateToNormalized(address recipient, address[] calldata tokens, uint256 nAmount) external {
        for(uint256 i=0; i<tokens.length; i++) {
            uint256 dnAmount = denormalizeTokenAmount(tokens[i], nAmount);
            Allocator(tokens[i]).allocateTo(recipient, dnAmount);
        }
    }

    function mint(address account, address[] calldata tokens, uint256[] calldata amounts) external {
        require(tokens.length == amounts.length, "BulkERC20Actions: tokens/amounts length mismatch");
        for(uint256 i=0; i<tokens.length; i++) {
            Mintable(tokens[i]).mint(account, amounts[i]);
        }
    }
    
    function mintNormalized(address recipient, address[] calldata tokens, uint256 nAmount) external {
        for(uint256 i=0; i<tokens.length; i++) {
            uint256 dnAmount = denormalizeTokenAmount(tokens[i], nAmount);
            Mintable(tokens[i]).mint(recipient, dnAmount);
        }
    }

   function transferFrom(address owner, address[] calldata recipients, address token, uint256[] calldata amounts) external {
        require(recipients.length == amounts.length, "BulkERC20Actions: tokens/amounts length mismatch");
        for(uint256 i=0; i<recipients.length; i++) {
            IERC20(token).transferFrom(owner, recipients[i], amounts[i]);
        }
    }

   function transferFrom(address owner, address[] calldata recipients, address token, uint256 amount) external {
        for(uint256 i=0; i<recipients.length; i++) {
            IERC20(token).transferFrom(owner, recipients[i], amount);
        }
    }

   function transferFrom(address owner, address recipient, address[] calldata tokens, uint256[] calldata amounts) external {
        require(tokens.length == amounts.length, "BulkERC20Actions: tokens/amounts length mismatch");
        for(uint256 i=0; i<tokens.length; i++) {
            IERC20(tokens[i]).transferFrom(owner, recipient, amounts[i]);
        }
    }

    function transferFromNormalized(address owner, address recipient, address[] calldata tokens, uint256 nAmount) external {
        for(uint256 i=0; i<tokens.length; i++) {
            uint256 dnAmount = denormalizeTokenAmount(tokens[i], nAmount);
            IERC20(tokens[i]).transferFrom(owner, recipient, dnAmount);
        }
    }
    
    function allowance(address token, address owner, address spender) public view returns(uint256) {
        return IERC20(token).allowance(owner, spender);
    }
    

    function normalizeTokenAmount(address token, uint256 amount) public view returns(uint256) {
        uint256 decimals = IERC20Detailed(token).decimals();
        return _normalizeTokenAmount(decimals, amount);
    }

    function denormalizeTokenAmount(address token, uint256 amount) public view returns(uint256) {
        uint256 decimals = IERC20Detailed(token).decimals();
        return _denormalizeTokenAmount(decimals, amount);
    }

    function _normalizeTokenAmount(uint256 decimals, uint256 amount) internal pure returns(uint256) {
        if (decimals == 18) {
            return amount;
        } else if (decimals > 18) {
            return amount.div(10**(decimals-18));
        } else if (decimals < 18) {
            return amount.mul(10**(18 - decimals));
        }
    }
    function _denormalizeTokenAmount(uint256 decimals, uint256 amount) internal pure returns(uint256) {
        if (decimals == 18) {
            return amount;
        } else if (decimals > 18) {
            return amount.mul(10**(decimals-18));
        } else if (decimals < 18) {
            return amount.div(10**(18 - decimals));
        }
    }
    
    
}