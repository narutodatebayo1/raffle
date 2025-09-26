## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

## Usage

### Build

```shell
$ anvil --fork-url https://reth-ethereum.ithaca.xyz/rpc
```

```shell
$ forge script script/Counter.s.sol:CounterScript --fork-url http://localhost:8545 --broadcast --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

```shell
$ forge test --fork-url https://reth-ethereum.ithaca.xyz/rpc
```