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

class ContractErrorDecoder {
  private interface: ethers.Interface;
  private errorMap: Map<string, any> = new Map();

  constructor(abi: any[]) {
    this.interface = new ethers.Interface(abi);
    this.buildErrorMap();
  }

  private buildErrorMap() {
    // Extract all error fragments from the ABI
    for (const fragment of this.interface.fragments) {
      if (fragment.type === "error") {
        const errorFragment = fragment as ethers.ErrorFragment;
        const selector = this.interface.getError(errorFragment.name)?.selector;
        if (selector) {
          this.errorMap.set(selector, errorFragment);
        }
      }
    }
    
    console.log("Found custom errors in contract:");
    this.errorMap.forEach((error, selector) => {
      console.log(`  ${selector}: ${error.name}`);
    });
  }

  decode(errorData: string): { name: string; args?: any[]; message: string } | null {
    if (!errorData || !errorData.startsWith('0x')) {
      return null;
    }

    try {
      // Try to parse the error using the interface
      const decodedError = this.interface.parseError(errorData);
      
      if (decodedError) {
        return {
          name: decodedError.name,
          args: decodedError.args ? Array.from(decodedError.args) : undefined,
          message: this.getErrorMessage(decodedError.name, decodedError.args)
        };
      }
    } catch (e) {
      // If parseError fails, try manual lookup
      const selector = errorData.slice(0, 10);
      const errorFragment = this.errorMap.get(selector);
      
      if (errorFragment) {
        return {
          name: errorFragment.name,
          args: undefined,
          message: `Custom error: ${errorFragment.name}`
        };
      }
    }

    // Unknown error
    const selector = errorData.slice(0, 10);
    return {
      name: "UnknownError",
      args: undefined,
      message: `Unknown custom error with selector: ${selector}`
    };
  }

  private getErrorMessage(errorName: string, args?: any[]): string {
    // Create human-readable messages for known errors
    const messages: Record<string, (args?: any[]) => string> = {
      "StakeNotFound": () => "The stake ID does not exist or is invalid",
      "UnauthorizedWithdrawal": () => "You are not the owner of this stake",
      "LockupNotCompleted": () => "The lockup period has not ended yet",
      "RewardAlreadyClaimed": () => "Rewards for this stake have already been claimed",
      "StakingNotLocked": () => "The stake has already been withdrawn",
      // Add more error messages as needed
    };

    const messageFunc = messages[errorName];
    if (messageFunc) {
      return messageFunc(args);
    }

    // Generic message with args if available
    if (args && args.length > 0) {
      return `${errorName}(${args.join(", ")})`;
    }
    
    return `Custom error: ${errorName}`;
  }

  getAllErrors(): { selector: string; name: string; inputs: any[] }[] {
    const errors: any[] = [];
    this.errorMap.forEach((error, selector) => {
      errors.push({
        selector,
        name: error.name,
        inputs: error.inputs || []
      });
    });
    return errors;
  }
}

async function testWithErrorHandling() {
  const provider = new ethers.JsonRpcProvider(RPC_URL);
  const wallet = new ethers.Wallet(PRIVATE_KEY, provider);
  const contract = new ethers.Contract(CONTRACT_ADDRESS, ABI, wallet);
  
  // Create error decoder
  const errorDecoder = new ContractErrorDecoder(ABI);
  
  // Display all available errors
  console.log("\nAll contract errors:");
  errorDecoder.getAllErrors().forEach(error => {
    console.log(`  ${error.selector}: ${error.name}`);
    if (error.inputs.length > 0) {
      console.log(`    Inputs: ${error.inputs.map((i: any) => `${i.name}: ${i.type}`).join(", ")}`);
    }
  });

  // Test claiming different stake IDs
  const stakeIds = [1, 2];
  
  for (const stakeId of stakeIds) {
    console.log(`\n${"=".repeat(50)}`);
    console.log(`Testing stake ID: ${stakeId}`);
    
    try {
      const tx = await contract.claimRewardsAndWithdraw(stakeId);
      await tx.wait();
      console.log(`✅ Successfully claimed stake #${stakeId}`);
    } catch (error: any) {
      console.log(`❌ Failed to claim stake #${stakeId}`);
      
      // Decode the error
      const errorData = error.data || error.info?.error?.data;
      if (errorData) {
        const decoded = errorDecoder.decode(errorData);
        if (decoded) {
          console.log(`\n🔍 Decoded Error:`);
          console.log(`   Name: ${decoded.name}`);
          console.log(`   Message: ${decoded.message}`);
          if (decoded.args) {
            console.log(`   Arguments: ${JSON.stringify(decoded.args)}`);
          }
        }
      }
      
      // Additional error details
      console.log(`\n📊 Raw Error Details:`);
      console.log(`   Error Data: ${errorData || "N/A"}`);
      console.log(`   From: ${error.transaction?.from || "N/A"}`);
      console.log(`   To: ${error.transaction?.to || "N/A"}`);
    }
  }
}

// Alternative: Manually compute error selectors
function computeErrorSelectors() {
  console.log("\nManually computing error selectors:");
  
  // Common error names to check
  const errorNames = [
    "StakeNotFound",
    "UnauthorizedWithdrawal",
    "LockupNotCompleted",
    "RewardAlreadyClaimed",
    "StakingNotLocked",
    "InvalidAmount",
    "InvalidDuration",
    "StakingPaused",
    // Add more potential error names
  ];

  errorNames.forEach(errorName => {
    // Compute selector: first 4 bytes of keccak256(errorName())
    const hash = ethers.keccak256(ethers.toUtf8Bytes(`${errorName}()`));
    const selector = hash.slice(0, 10);
    console.log(`  ${errorName}: ${selector}`);
  });
}

// Run the test
testWithErrorHandling().catch(console.error);

// Uncomment to see manual selector computation
// computeErrorSelectors();