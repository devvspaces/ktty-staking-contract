#!/bin/bash

cast send \
  --rpc-url "$RPC_URL" \
  --private-key "$PRIVATE_KEY" \
  "$STAKING_CONTRACT_ADDRESS" \
  "addTier(string,uint256,uint256,uint256,uint256)" \
  "Tier 1" \
  "$(cast --to-wei "1")"  \
  "$(cast --to-wei "10")"  \
  30 \
  20000 \
  --legacy


cast send \
  --rpc-url "$RPC_URL" \
  --private-key "$PRIVATE_KEY" \
  "$STAKING_CONTRACT_ADDRESS" \
  "addTier(string,uint256,uint256,uint256,uint256)" \
  "Intermediate" \
  "$(cast --to-wei "11")"  \
  "$(cast --to-wei "15")"  \
  60 \
  40000 \
  --legacy


cast send \
  --rpc-url "$RPC_URL" \
  --private-key "$PRIVATE_KEY" \
  "$STAKING_CONTRACT_ADDRESS" \
  "addTier(string,uint256,uint256,uint256,uint256)" \
  "Advanced" \
  "$(cast --to-wei "16")"  \
  "$(cast --to-wei "20")"  \
  90 \
  100000 \
  --legacy


cast send \
  --rpc-url "$RPC_URL" \
  --private-key "$PRIVATE_KEY" \
  "$STAKING_CONTRACT_ADDRESS" \
  "addTier(string,uint256,uint256,uint256,uint256)" \
  "Diamond" \
  "$(cast --to-wei "21")"  \
  "$(cast --to-wei "40")"  \
  90 \
  150000 \
  --legacy


cast send \
  --rpc-url "$RPC_URL" \
  --private-key "$PRIVATE_KEY" \
  "$STAKING_CONTRACT_ADDRESS" \
  "addTier(string,uint256,uint256,uint256,uint256)" \
  "Platinum" \
  "$(cast --to-wei "41")"  \
  "$(cast --to-wei "60")"  \
  180 \
  250000 \
  --legacy