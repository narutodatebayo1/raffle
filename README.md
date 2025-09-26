## Test

Before running test, you must edit solidity version in lib\chainlink-brownie-contracts\contracts\src\v0.8\vrf\dev\VRFV2PlusWrapper.sol

```shell
from pragma solidity 0.8.19;
  to pragma solidity ^0.8.19;
```

To run test, use this command

```shell
$ forge test --via-ir
```
