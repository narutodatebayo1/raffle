// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {MyNFT} from "../src/MyNFT.sol";

contract MyNFTTest is Test {
    MyNFT public myNFT;
    address public constant USER1 = address(1);

    function setUp() public {
        myNFT = new MyNFT();
    }

    function test_Mint() public {
        vm.prank(USER1);
        uint256 tokenId = myNFT.mint();

        assertEq(myNFT.ownerOf(tokenId), USER1);
    }
}
