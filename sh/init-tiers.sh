#!/bin/bash

cast send \
  --rpc-url "$RPC_URL" \
  --private-key "$PRIVATE_KEY" \
  "$STAKING_CONTRACT_ADDRESS" \
  "addTier(string,uint256,uint256,uint256,uint256)" \
  "Entry" \
  "$(cast --to-wei "1000000")"  \
  "$(cast --to-wei "2900000")"  \
  30 \
  20000 \
  --legacy


cast send \
  --rpc-url "$RPC_URL" \
  --private-key "$PRIVATE_KEY" \
  "$STAKING_CONTRACT_ADDRESS" \
  "addTier(string,uint256,uint256,uint256,uint256)" \
  "Intermediate" \
  "$(cast --to-wei "3000000")"  \
  "$(cast --to-wei "5900000")"  \
  60 \
  40000 \
  --legacy


cast send \
  --rpc-url "$RPC_URL" \
  --private-key "$PRIVATE_KEY" \
  "$STAKING_CONTRACT_ADDRESS" \
  "addTier(string,uint256,uint256,uint256,uint256)" \
  "Advanced" \
  "$(cast --to-wei "6000000")"  \
  "$(cast --to-wei "9900000")"  \
  90 \
  100000 \
  --legacy


cast send \
  --rpc-url "$RPC_URL" \
  --private-key "$PRIVATE_KEY" \
  "$STAKING_CONTRACT_ADDRESS" \
  "addTier(string,uint256,uint256,uint256,uint256)" \
  "Diamond" \
  "$(cast --to-wei "10000000")"  \
  "$(cast --to-wei "19900000")"  \
  90 \
  150000 \
  --legacy


cast send \
  --rpc-url "$RPC_URL" \
  --private-key "$PRIVATE_KEY" \
  "$STAKING_CONTRACT_ADDRESS" \
  "addTier(string,uint256,uint256,uint256,uint256)" \
  "Platinum" \
  "$(cast --to-wei "20000000")"  \
  "$(cast --to-wei "50000000")"  \
  180 \
  250000 \
  --legacy