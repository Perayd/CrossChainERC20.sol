// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IMintableToken {
    function mint(address to, uint256 amount) external;
}

contract BridgeDest is ReentrancyGuard, Ownable {
    using ECDSA for bytes32;

    IMintableToken public token;
    address public relayerSigner; // public key that signs attestation
    mapping(bytes32 => bool) public processed; // track processed deposits

    event Claim(address indexed recipient, uint256 amount, uint256 nonce, uint256 srcChainId, bytes32 depositId);

    constructor(address tokenAddress, address relayerSigner_) {
        token = IMintableToken(tokenAddress);
        relayerSigner = relayerSigner_;
    }

    function setRelayerSigner(address s) external onlyOwner {
        relayerSigner = s;
    }

    /// @notice claim tokens on destination chain using relayer's signature
    /// @param sender original depositor on source chain (for audit)
    /// @param recipient who receives tokens on dest chain
    /// @param amount amount to mint
    /// @param srcChainId chain id of source
    /// @param nonce unique deposit nonce from source
    /// @param signature signature produced by relayerSigner over the deposit payload
    function claim(
        address sender,
        address recipient,
        uint256 amount,
        uint256 srcChainId,
        uint256 nonce,
        bytes calldata signature
    ) external nonReentrant {
        require(amount > 0, "zero amount");
        // Compose the deposit id/hash
        bytes32 depositHash = keccak256(abi.encodePacked(sender, recipient, amount, srcChainId, nonce));
        require(!processed[depositHash], "already processed");

        // Verify signature
        bytes32 ethSigned = depositHash.toEthSignedMessageHash();
        address recovered = ethSigned.recover(signature);
        require(recovered == relayerSigner, "invalid signature");

        processed[depositHash] = true;

        // mint tokens on dest chain to the recipient
        token.mint(recipient, amount);

        emit Claim(recipient, amount, nonce, srcChainId, depositHash);
    }
}
