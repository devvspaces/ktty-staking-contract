const { createClient } = require("@supabase/supabase-js");
const { ethers, formatEther } = require("ethers");
const dotenv = require("dotenv");
const fs = require("fs").promises;
const path = require("path");
const Redis = require("ioredis");

dotenv.config({
  path: "../.env",
});

POLL_TIME_INTERVAL = 300000; // milliseconds

// Supabase setup
const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_KEY;
const supabase = createClient(supabaseUrl, supabaseKey);

// Blockchain setup
const provider = new ethers.JsonRpcProvider(process.env.RPC_URL);
const wsProvider = process.env.WS_URL
  ? new ethers.WebSocketProvider(process.env.WS_URL)
  : null;

const stakingAddress = process.env.STAKING_CONTRACT_ADDRESS;
const stakingABI = require("../out/KTTYStaking.sol/KTTYStaking.json").abi;
const stakingContract = new ethers.Contract(
  stakingAddress,
  stakingABI,
  provider
);
const wsStakingContract = wsProvider
  ? new ethers.Contract(stakingAddress, stakingABI, wsProvider)
  : null;

// Set up event filters
const tierCreatedFilter = stakingContract.filters.TierCreated();
const tierUpdatedFilter = stakingContract.filters.TierUpdated();
const stakedFilter = stakingContract.filters.Staked();
const stakeWithdrawnFilter = stakingContract.filters.StakeWithdrawn();
const rewardClaimedFilter = stakingContract.filters.RewardClaimed();
const rewardTokenRegisteredFilter =
  stakingContract.filters.RewardTokenRegistered();
const rewardTokenUpdatedFilter = stakingContract.filters.RewardTokenUpdated();
const tierRewardTokenAddedFilter =
  stakingContract.filters.TierRewardTokenAdded();
const tierRewardTokenRemovedFilter =
  stakingContract.filters.TierRewardTokenRemoved();

// Track the last processed block to resume indexing
let lastProcessedBlock;

// Create Redis client - configure as needed
const redis = new Redis({
  host: process.env.REDIS_HOST || "localhost",
  port: process.env.REDIS_PORT || 6379,
  db: process.env.REDIS_DB || 0,
});

// Redis key for storing the last processed block
const BLOCK_KEY = "indexer:lastProcessedBlock";

// Function to read the last processed block from file
// Function to read the last processed block from Redis
async function loadLastProcessedBlock() {
  try {
    const value = await redis.get(BLOCK_KEY);
    if (value) {
      return parseInt(value, 10);
    }
    // If not found in Redis, return default
    const currentBlock = await provider.getBlockNumber();
    return parseInt(process.env.STARTING_BLOCK || currentBlock.toString());
  } catch (error) {
    console.error("Error loading last processed block from Redis:", error);
    throw error;
  }
}

// Function to save the last processed block to Redis
async function saveLastProcessedBlock(blockNumber) {
  try {
    await redis.set(BLOCK_KEY, blockNumber);
    lastProcessedBlock = blockNumber;
    console.log(`Last processed block updated to: ${lastProcessedBlock}`);
  } catch (error) {
    console.error("Error saving last processed block to Redis:", error);
    throw error;
  }
}

async function handleTierCreated(event) {
  const { tierId, name, minStake, lockupPeriod, apy } = event.args;

  // Query contract for maxStake (not in event)
  const tier = await stakingContract.tiers(tierId);

  // Check if already in supabase
  const { data: existingTier, error: existingTierError } = await supabase
    .from("tiers")
    .select("*")
    .eq("id", tierId.toString())
    .single();
  if (existingTierError && existingTierError.code !== "PGRST116") {
    console.error("Error checking existing tier:", existingTierError);
    return;
  }
  if (existingTier) {
    console.log(`Tier ${tierId} already exists, skipping creation.`);
    return;
  }

  await supabase.from("tiers").insert({
    id: tierId.toString(),
    name,
    min_stake: parseFloat(formatEther(minStake)),
    max_stake: parseFloat(formatEther(tier.maxStake)),
    lockup_period: lockupPeriod.toString(),
    apy: apy.toString(),
    is_active: true,
  });
}

async function handleTierUpdated(event) {
  const { tierId, name, minStake, lockupPeriod, apy, isActive } = event.args;
  const tier = await stakingContract.tiers(tierId);
  await supabase
    .from("tiers")
    .update({
      name,
      min_stake: parseFloat(formatEther(minStake)),
      max_stake: parseFloat(formatEther(tier.maxStake)),
      lockup_period: lockupPeriod.toString(),
      apy: apy.toString(),
      is_active: isActive,
    })
    .eq("id", tierId.toString());
}

async function handleRewardTokenRegistered(event) {
  const { tokenAddress, symbol, rewardRate } = event.args;

  // Check if already in supabase
  const { data: existingToken, error: existingTokenError } = await supabase
    .from("reward_tokens")
    .select("*")
    .eq("address", tokenAddress)
    .single();

  if (existingTokenError && existingTokenError.code !== "PGRST116") {
    console.error("Error checking existing token:", existingTokenError);
    return;
  }

  if (existingToken) {
    console.log(
      `Reward token ${tokenAddress} already exists, skipping creation.`
    );
    return;
  }

  await supabase.from("reward_tokens").insert({
    address: tokenAddress,
    symbol: symbol,
    reward_rate: Number(rewardRate),
    is_active: true,
  });
}

async function handleRewardTokenUpdated(event) {
  const { tokenAddress, symbol, rewardRate } = event.args;

  await supabase
    .from("reward_tokens")
    .update({
      symbol: symbol,
      reward_rate: rewardRate,
    })
    .eq("address", tokenAddress);
}

async function handleTierRewardTokenAdded(event) {
  const { tierId, tokenAddress } = event.args;

  // Check if already in supabase
  const { data: existingToken, error: existingTokenError } = await supabase
    .from("tier_reward_tokens")
    .select("*")
    .eq("tier_id", tierId.toString())
    .eq("token_address", tokenAddress)
    .single();

  if (existingTokenError && existingTokenError.code !== "PGRST116") {
    console.error("Error checking existing token:", existingTokenError);
    return;
  }
  if (existingToken) {
    console.log(
      `Tier reward token ${tokenAddress} already exists for tier ${tierId}, skipping addition.`
    );
    return;
  }

  await supabase.from("tier_reward_tokens").insert({
    tier_id: tierId.toString(),
    token_address: tokenAddress,
  });
}

async function handleTierRewardTokenRemoved(event) {
  const { tierId, tokenAddress } = event.args;

  await supabase
    .from("tier_reward_tokens")
    .delete()
    .eq("tier_id", tierId.toString())
    .eq("token_address", tokenAddress);
}

async function handleStaked(event) {
  const { stakeId, owner, amount, tierId, startTime, endTime } = event.args;

  // Check if already in supabase
  const { data: existingStake, error: existingStakeError } = await supabase
    .from("stakes")
    .select("*")
    .eq("id", stakeId.toString())
    .single();
  if (existingStakeError && existingStakeError.code !== "PGRST116") {
    console.error("Error checking existing stake:", existingStakeError);
    return;
  }
  if (existingStake) {
    console.log(`Stake ${stakeId} already exists, skipping creation.`);
    return;
  }

  await supabase.from("stakes").insert({
    id: stakeId.toString(),
    owner,
    amount: parseFloat(formatEther(amount)),
    tier_id: tierId.toString(),
    start_time: startTime.toString(),
    end_time: endTime.toString(),
    has_withdrawn: false,
    has_claimed_rewards: false,
  });
}

async function handleStakeWithdrawn(event) {
  const { stakeId } = event.args;

  await supabase
    .from("stakes")
    .update({ has_withdrawn: true })
    .eq("id", stakeId.toString());
}

async function handleRewardClaimed(event) {
  const { stakeId, owner, token, amount } = event.args;

  // Check if already in supabase
  const { data: existingClaim, error: existingClaimError } = await supabase
    .from("reward_claims")
    .select("*")
    .eq("stake_id", stakeId.toString())
    .eq("owner", owner)
    .eq("token_address", token)
    .single();
  if (existingClaimError && existingClaimError.code !== "PGRST116") {
    console.error("Error checking existing claim:", existingClaimError);
    return;
  }
  if (existingClaim) {
    console.log(
      `Reward claim for stake ${stakeId} already exists, skipping creation.`
    );
    return;
  }

  await supabase.from("reward_claims").insert({
    stake_id: stakeId.toString(),
    owner,
    token_address: token,
    amount: formatEther(amount),
    block_timestamp: event.blockNumber,
    transaction_hash: event.transactionHash,
  });

  await supabase
    .from("stakes")
    .update({ has_claimed_rewards: true })
    .eq("id", stakeId.toString());
}

const EventHandlers = {
  TierCreated: {
    handler: handleTierCreated,
    filter: tierCreatedFilter,
  },
  TierUpdated: {
    handler: handleTierUpdated,
    filter: tierUpdatedFilter,
  },
  Staked: {
    handler: handleStaked,
    filter: stakedFilter,
  },
  StakeWithdrawn: {
    handler: handleStakeWithdrawn,
    filter: stakeWithdrawnFilter,
  },
  RewardClaimed: {
    handler: handleRewardClaimed,
    filter: rewardClaimedFilter,
  },
  RewardTokenRegistered: {
    handler: handleRewardTokenRegistered,
    filter: rewardTokenRegisteredFilter,
  },
  RewardTokenUpdated: {
    handler: handleRewardTokenUpdated,
    filter: rewardTokenUpdatedFilter,
  },
  TierRewardTokenAdded: {
    handler: handleTierRewardTokenAdded,
    filter: tierRewardTokenAddedFilter,
  },
  TierRewardTokenRemoved: {
    handler: handleTierRewardTokenRemoved,
    filter: tierRewardTokenRemovedFilter,
  },
};

async function processHandlers(fromBlock, toBlock) {
  for (const [_, { handler, filter }] of Object.entries(EventHandlers)) {
    // console.log(`Processing ${eventName} events`);
    const events = await stakingContract.queryFilter(
      filter,
      fromBlock,
      toBlock
    );
    for (const event of events) {
      await handler(event);
    }
  }

  await saveLastProcessedBlock(toBlock);
}

async function startIndexing() {
  try {
    lastProcessedBlock = await loadLastProcessedBlock();
    const currentBlock = await provider.getBlockNumber();
    const batchSize = parseInt(process.env.INDEXER_BATCH_SIZE ?? "500");

    console.log(
      `Starting indexing from block ${lastProcessedBlock} to ${currentBlock} with batch size ${batchSize}`
    );

    for (
      let fromBlock = Number(lastProcessedBlock);
      fromBlock <= currentBlock;
      fromBlock += batchSize
    ) {
      const toBlock = Math.min(fromBlock + batchSize - 1, currentBlock);
      console.log(`Processing blocks ${fromBlock} to ${toBlock}`);
      await processHandlers(fromBlock, toBlock);
    }
  } catch (error) {
    console.error("Error in startIndexing:", error);
    console.log(
      `Error processing blocks. Retrying in ${
        POLL_TIME_INTERVAL / 1000
      } seconds...`
    );
    setTimeout(startIndexing, POLL_TIME_INTERVAL);
  }

  console.log(`Finished processing historical events`);

  const usePolling = process.env.USE_POLLING === "true";

  // Start listening for new events
  if (usePolling) {
    setTimeout(startIndexing, POLL_TIME_INTERVAL);
    console.log(
      `Listening for new events using polling every ${
        POLL_TIME_INTERVAL / 1000
      } seconds...`
    );
  } else if (wsStakingContract) {
    console.log("Listening for new events using WebSocket...");
    wsStakingContract.on(tierCreatedFilter, handleTierCreated);
    wsStakingContract.on(tierUpdatedFilter, handleTierUpdated);
    wsStakingContract.on(stakedFilter, handleStaked);
    wsStakingContract.on(stakeWithdrawnFilter, handleStakeWithdrawn);
    wsStakingContract.on(rewardClaimedFilter, handleRewardClaimed);
    wsStakingContract.on(
      rewardTokenRegisteredFilter,
      handleRewardTokenRegistered
    );
    wsStakingContract.on(rewardTokenUpdatedFilter, handleRewardTokenUpdated);
    wsStakingContract.on(
      tierRewardTokenAddedFilter,
      handleTierRewardTokenAdded
    );
    wsStakingContract.on(
      tierRewardTokenRemovedFilter,
      handleTierRewardTokenRemoved
    );
    console.log("Listening for new events...");
  }
}

// Handle errors and ensure clean shutdown
process.on("SIGINT", async () => {
  console.log("Shutting down indexer...");
  stakingContract.removeAllListeners();
  process.exit(0);
});

// Start the indexer
console.log(`Starting indexer`);
startIndexing().catch((error) => {
  console.error(error);
  process.exit(1);
});
