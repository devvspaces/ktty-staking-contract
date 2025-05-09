## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```


```shell
forge create \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --constructor-args "RoninNFT" "RNFT" "https://peach-necessary-primate-505.mypinata.cloud/ipfs/bafkreiapgfyjvlyrqy6pnk5k2z63x7v7d7rlh4ju6tiz6iqsntawxm4hwu" 0x5fbdb2315678afecb367f032d93f642f64180aa3 0xe7f1725e7734ce288f8367e1bb143e90bb3f0512 1744470000 \
  --verify \
  src/RoninNFT.sol:RoninNFT
```

## Deployment steps

### Setup the environment variables

Copy the `.env.example` file to `.env` and fill in the required values.

```shell
cp .env.example .env
```

Source the `.env` file to load the environment variables.

```shell
source .env
```

### Deploy the contract

Make sure you have the required dependencies installed.

```shell
forge install
forge build
```

Run the deployment script.

```shell
forge script script/DeployKTTYStakingUpgradeable.s.sol --rpc-url $RPC_URL --broadcast --private-key $PRIVATE_KEY
```

Verify the contract on Roninchain.

```shell
forge verify-contract --verifier sourcify --verifier-url https://sourcify.roninchain.com/server/ --chain-id 2020 $CONTRACT_ADDRESS src/KTTYStaking.sol:KTTYStaking
```

### Create tiers

Copy the commands in `init-tiers.sh` to create the tiers in the staking contract.

### Create reward tokens

```shell
cast send \
  --rpc-url "$RPC_URL" \
  --private-key "$PRIVATE_KEY" \
  "$STAKING_CONTRACT_ADDRESS" \
  "registerRewardToken(address,string,uint256)" \
  "ADDRESS_HERE" \
  "SYMBOL_HERE"  \
  1  \
  --legacy
```





















```shell
forge script script/MockToken.s.sol --rpc-url $RPC_URL --broadcast --private-key $PRIVATE_KEY

forge script script/KTTYStaking.s.sol --rpc-url $RPC_URL --broadcast --private-key $PRIVATE_KEY

forge verify-contract --verifier sourcify --verifier-url https://sourcify.roninchain.com/server/ --chain-id 2020 $CONTRACT_ADDRESS src/KTTYStaking.sol:KTTYStaking

forge script script/Token.s.sol --rpc-url $RPC_URL --broadcast --private-key $PRIVATE_KEY

# Add a new tier to the staking contract
cast send \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  $STAKING_CONTRACT_ADDRESS \
  "addTier(string,uint256,uint256,uint256,uint256)" \
  "Tier 1" \
  $(cast --to-wei "1")  \
  $(cast --to-wei "10")  \
  30 \
  20000 \
  --legacy

# Update a tier on the staking contract
cast send \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  $STAKING_CONTRACT_ADDRESS \
  "updateTier(uint256,string,uint256,uint256,uint256,uint256,bool)" \
  1 \
  "Entry" \
  $(cast --to-wei "1000000")  \
  $(cast --to-wei "2900000")  \
  30 \
  20000 \
  true \
  --legacy

  
cast send \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  $STAKING_CONTRACT_ADDRESS \
  "updateTier(uint256,string,uint256,uint256,uint256,uint256,bool)" \
  2 \
  "Intermediate" \
  $(cast --to-wei "3000000")  \
  $(cast --to-wei "5900000")  \
  60 \
  40000 \
  true \
  --legacy

  
cast send \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  $STAKING_CONTRACT_ADDRESS \
  "updateTier(uint256,string,uint256,uint256,uint256,uint256,bool)" \
  3 \
  "Advanced" \
  $(cast --to-wei "6000000")  \
  $(cast --to-wei "9900000")  \
  90 \
  100000 \
  true \
  --legacy

  
cast send \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  $STAKING_CONTRACT_ADDRESS \
  "updateTier(uint256,string,uint256,uint256,uint256,uint256,bool)" \
  4 \
  "Diamond" \
  $(cast --to-wei "10000000")  \
  $(cast --to-wei "19900000")  \
  120 \
  150000 \
  true \
  --legacy

  
cast send \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  $STAKING_CONTRACT_ADDRESS \
  "updateTier(uint256,string,uint256,uint256,uint256,uint256,bool)" \
  5 \
  "Platinum" \
  $(cast --to-wei "20000000")  \
  $(cast --to-wei "50000000")  \
  180 \
  250000 \
  true \
  --legacy


# Mint tokens

cast send \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  "0x4c24d08Cd47894C7Af961325895381CB4216fd4D" \
  "mint(address,uint256)" \
  "0xA0Ca70DFB6Fb79fD5EF160D3EAc677868547ffEF" \
  $(cast --to-wei "2000000000")  \
  --legacy

cast send \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  "0x6F03FC28999a9230A5C8650b8d440098A8B52294" \
  "allowance(address,address)" \
  "0xA0Ca70DFB6Fb79fD5EF160D3EAc677868547ffEF" \
  "0xEdE2bFf384ca4cfdBe4165ED7A02a55D1e10396c" \
  --legacy


# Stake

cast send \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  "0xEdE2bFf384ca4cfdBe4165ED7A02a55D1e10396c" \
  "stake(uint256,uint256)" \
  $(cast --to-wei "1000000")  \
  1 \
  --legacy
  
```
