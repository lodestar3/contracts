// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ERC721Demo is ERC721, Ownable {
    constructor() ERC721("Demo NFT", "DNT") Ownable(msg.sender) {}

    function mint(address to, uint256 tokenId) public onlyOwner {
        _mint(to, tokenId);
    }
}
