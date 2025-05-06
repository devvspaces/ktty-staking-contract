#!/bin/bash

cast send \
  --rpc-url "$RPC_URL" \
  --private-key "$PRIVATE_KEY" \
  "$STAKING_CONTRACT_ADDRESS" \
  "addRewardTokenToTier(uint256,address)" \
  2 \
  "0x80121CbdDab8B5480b866A17535993002BB978cF" \
  --legacy


cast send \
  --rpc-url "$RPC_URL" \
  --private-key "$PRIVATE_KEY" \
  "$STAKING_CONTRACT_ADDRESS" \
  "addRewardTokenToTier(uint256,address)" \
  3 \
  "0x80121CbdDab8B5480b866A17535993002BB978cF" \
  --legacy && \
cast send \
  --rpc-url "$RPC_URL" \
  --private-key "$PRIVATE_KEY" \
  "$STAKING_CONTRACT_ADDRESS" \
  "addRewardTokenToTier(uint256,address)" \
  3 \
  "0x281Aa0b2Be24F24879D9B8e4b8E08354fA28ea7F" \
  --legacy && \
cast send \
  --rpc-url "$RPC_URL" \
  --private-key "$PRIVATE_KEY" \
  "$STAKING_CONTRACT_ADDRESS" \
  "addRewardTokenToTier(uint256,address)" \
  3 \
  "0x8A4De34a8c803C9392D5E469861135e761260Ccf" \
  --legacy && \
cast send \
  --rpc-url "$RPC_URL" \
  --private-key "$PRIVATE_KEY" \
  "$STAKING_CONTRACT_ADDRESS" \
  "addRewardTokenToTier(uint256,address)" \
  3 \
  "0x4c24d08Cd47894C7Af961325895381CB4216fd4D" \
  --legacy


cast send \
  --rpc-url "$RPC_URL" \
  --private-key "$PRIVATE_KEY" \
  "$STAKING_CONTRACT_ADDRESS" \
  "addRewardTokenToTier(uint256,address)" \
  4 \
  "0x80121CbdDab8B5480b866A17535993002BB978cF" \
  --legacy && \
cast send \
  --rpc-url "$RPC_URL" \
  --private-key "$PRIVATE_KEY" \
  "$STAKING_CONTRACT_ADDRESS" \
  "addRewardTokenToTier(uint256,address)" \
  4 \
  "0x281Aa0b2Be24F24879D9B8e4b8E08354fA28ea7F" \
  --legacy && \
cast send \
  --rpc-url "$RPC_URL" \
  --private-key "$PRIVATE_KEY" \
  "$STAKING_CONTRACT_ADDRESS" \
  "addRewardTokenToTier(uint256,address)" \
  4 \
  "0x8A4De34a8c803C9392D5E469861135e761260Ccf" \
  --legacy && \
cast send \
  --rpc-url "$RPC_URL" \
  --private-key "$PRIVATE_KEY" \
  "$STAKING_CONTRACT_ADDRESS" \
  "addRewardTokenToTier(uint256,address)" \
  4 \
  "0x4c24d08Cd47894C7Af961325895381CB4216fd4D" \
  --legacy




cast send \
  --rpc-url "$RPC_URL" \
  --private-key "$PRIVATE_KEY" \
  "$STAKING_CONTRACT_ADDRESS" \
  "addRewardTokenToTier(uint256,address)" \
  5 \
  "0x80121CbdDab8B5480b866A17535993002BB978cF" \
  --legacy && \
cast send \
  --rpc-url "$RPC_URL" \
  --private-key "$PRIVATE_KEY" \
  "$STAKING_CONTRACT_ADDRESS" \
  "addRewardTokenToTier(uint256,address)" \
  5 \
  "0x281Aa0b2Be24F24879D9B8e4b8E08354fA28ea7F" \
  --legacy && \
cast send \
  --rpc-url "$RPC_URL" \
  --private-key "$PRIVATE_KEY" \
  "$STAKING_CONTRACT_ADDRESS" \
  "addRewardTokenToTier(uint256,address)" \
  5 \
  "0x8A4De34a8c803C9392D5E469861135e761260Ccf" \
  --legacy && \
cast send \
  --rpc-url "$RPC_URL" \
  --private-key "$PRIVATE_KEY" \
  "$STAKING_CONTRACT_ADDRESS" \
  "addRewardTokenToTier(uint256,address)" \
  5 \
  "0x4c24d08Cd47894C7Af961325895381CB4216fd4D" \
  --legacy

