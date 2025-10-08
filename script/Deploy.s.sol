// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {MyNFT} from "../src/MyNFT.sol";
import {Raffle} from "../src/Raffle.sol";

contract DeployScript is Script {
    MyNFT public myNFT;
    Raffle public raffle;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        myNFT = new MyNFT();
        raffle = new Raffle(
            address(0x195f15F2d49d693cE265b4fB0fdDbE15b1850Cc1),
            1e18,
            100,
            address(myNFT)
        );

        vm.stopBroadcast();
    }
}
