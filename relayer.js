require('dotenv').config();
const { ethers } = require('ethers');

const SRC_RPC = process.env.SRC_RPC; // source chain RPC
const DEST_RPC = process.env.DEST_RPC; // dest chain RPC (optional if just signing)
const RELAYER_PRIVATE_KEY = process.env.RELAYER_KEY;
const SOURCE_BRIDGE_ADDRESS = process.env.SOURCE_BRIDGE;
const SOURCE_BRIDGE_ABI = [
  "event Deposit(address indexed sender, address indexed recipient, uint256 amount, uint256 nonce, uint256 indexed dstChainId)"
];

async function main() {
  const provider = new ethers.providers.JsonRpcProvider(SRC_RPC);
  const wallet = new ethers.Wallet(RELAYER_PRIVATE_KEY, provider);
  const bridge = new ethers.Contract(SOURCE_BRIDGE_ADDRESS, SOURCE_BRIDGE_ABI, provider);

  console.log("Relayer running, watching Deposit events...");

  bridge.on("Deposit", async (sender, recipient, amount, nonce, dstChainId, event) => {
    try {
      console.log("Deposit:", { sender, recipient, amount: amount.toString(), nonce: nonce.toString(), dstChainId: dstChainId.toString() });

      // Create the same hash used in BridgeDest: keccak256(sender, recipient, amount, srcChainId, nonce)
      const srcChainId = (await provider.getNetwork()).chainId;

      const hash = ethers.utils.solidityKeccak256(
        ["address","address","uint256","uint256","uint256"],
        [sender, recipient, amount, srcChainId, nonce]
      );

      // Sign the hash as Ethereum Signed Message
      const signature = await wallet.signMessage(ethers.utils.arrayify(hash));

      // Deliver signature to user (off-chain) or push to a service; often returning to user is common:
      // In many designs, relayer calls destination contract.claim(...) with the signature (if it has RPC)
      // Or stores until user presents signature to the destination contract.

      console.log("Signature (attestation):", signature);
      // Optional: auto-call destination chain (if you have DEST_RPC and wallet connected to dest)
      // else, the signature is returned to the user who will call BridgeDest.claim(...)
    } catch (err) {
      console.error("Relayer error:", err);
    }
  });
}

main().catch(console.error);
