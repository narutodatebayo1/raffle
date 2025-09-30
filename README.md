# Raffle

## Install

To install, use this command

```shell
$ forge install
```

## Test

Before running test, you must edit solidity version in `lib\chainlink-brownie-contracts\contracts\src\v0.8\vrf\dev\VRFV2PlusWrapper.sol`

From:

```shell
pragma solidity 0.8.19;
```

To:

```shell
pragma solidity ^0.8.19;
```

To run test, use this command

```shell
$ forge test --via-ir
```
