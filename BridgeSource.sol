// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BridgeSource is ReentrancyGuard {
    IERC20 public token;
    address public admin;
    uint256 public depositCount;

    event Deposit(
        address indexed sender,
        address indexed recipient,
        uint256 amount,
        uint256 nonce,
        uint256 indexed dstChainId
    );

    modifier onlyAdmin() {
        require(msg.sender == admin, "not admin");
        _;
    }

    constructor(address tokenAddress, address admin_) {
        token = IERC20(tokenAddress);
        admin = admin_;
        depositCount = 0;
    }

    /// @notice user approves token to this contract first
    function deposit(address recipient, uint256 amount, uint256 dstChainId) external nonReentrant {
        require(amount > 0, "zero amount");
        // transfer tokens from user into this bridge contract (locks them)
        require(token.transferFrom(msg.sender, address(this), amount), "transferFrom failed");

        uint256 nonce = ++depositCount;
        emit Deposit(msg.sender, recipient, amount, nonce, dstChainId);
    }

    /// @notice admin can withdraw locked tokens (for emergency or finalize)
    function adminWithdraw(address to, uint256 amount) external onlyAdmin {
        require(token.transfer(to, amount), "withdraw failed");
    }

    function setAdmin(address newAdmin) external onlyAdmin {
        admin = newAdmin;
    }
}
