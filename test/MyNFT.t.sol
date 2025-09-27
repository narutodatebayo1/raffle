// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {MyNFT} from "../src/MyNFT.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract MyNFTTest is Test {
    MyNFT public myNFT;

    address public constant OWNER = address(100);
    address public constant USER1 = address(1);

    function setUp() public {
        vm.prank(OWNER);
        myNFT = new MyNFT();
    }

    function test_Mint() public {
        vm.prank(OWNER);
        uint256 tokenId = myNFT.mint();

        assertEq(myNFT.ownerOf(tokenId), OWNER);
    }

    function test_Mint_RevertIf_NotOwner() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, USER1));
        vm.prank(USER1);
        myNFT.mint();
    }
}
