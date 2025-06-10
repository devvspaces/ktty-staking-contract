import { ethers } from "ethers";
import dotenv from "dotenv";
dotenv.config({
  path: "./.env",
});

// Load environment variables
const RPC_URL = process.env.RPC_URL as string;
const PRIVATE_KEY = process.env.PRIVATE_KEY as string;
const CONTRACT_ADDRESS = process.env.STAKING_CONTRACT_ADDRESS as string;
const ABI = require("./out/KTTYStaking.sol/KTTYStaking.json").abi;

async function main() {
  // Setup provider, signer, and contract
  const provider = new ethers.JsonRpcProvider(RPC_URL);
  const wallet = new ethers.Wallet(PRIVATE_KEY, provider);
  const contract = new ethers.Contract(CONTRACT_ADDRESS, ABI, wallet);

  let tx = await contract.claimRewardsAndWithdraw(2);
  await tx.wait();
  console.log(`Stake claimed`);
}

main().catch((err) => {
  console.error("Error during phase update:", err);
});