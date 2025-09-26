// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MyNFT is ERC721 {
    uint256 private count;

    constructor() ERC721("MyNFT", "NFT") {}

    function mint() external returns (uint256) {
        count++;
        _mint(msg.sender, count);
        return count;
    }
}
