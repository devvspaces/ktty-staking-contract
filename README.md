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

```shell
forge script script/MockToken.s.sol --rpc-url $RPC_URL --broadcast --private-key $PRIVATE_KEY

forge script script/KTTYStaking.s.sol --rpc-url $RPC_URL --broadcast --private-key $PRIVATE_KEY

forge verify-contract --verifier sourcify --verifier-url https://sourcify.roninchain.com/server/ --chain-id 2020 $CONTRACT_ADDRESS src/KTTYStaking.sol:KTTYStaking

forge script script/Token.s.sol --rpc-url $RPC_URL --broadcast --private-key $PRIVATE_KEY

cast send \
  --rpc-url $RONIN_RPC_URL \
  --private-key $PRIVATE_KEY \
  0x49B6Af6116222777575e65dbB2b7CDaaF50787F3 \
  "mint(address,uint256)" \
  0xA0Ca70DFB6Fb79fD5EF160D3EAc677868547ffEF \
  1000000000000000000000000000  \
  --legacy

  cast send \
  --rpc-url $RONIN_RPC_URL \
  --private-key $PRIVATE_KEY \
  0x4E5932906ad152071bA0253840bDE1Ab748D3917 \
  "startPhase(uint8)" \
  1 \
  --legacy
```
