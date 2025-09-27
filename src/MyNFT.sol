// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MyNFT is Ownable, ERC721 {
    uint256 private count;

    constructor() Ownable(msg.sender) ERC721("MyNFT", "NFT") {}

    function mint() external onlyOwner returns (uint256) {
        count++;
        _mint(owner(), count);
        return count;
    }
}
