// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract TestLaunchPadMinter is ERC721 {
    uint256 public tokenId = 1;

    mapping(address => mapping(uint256 => uint256)) public levels;

    constructor() ERC721("DEMO", "DEMO") {

  }
    function mint(address user, uint256 level) public {
        _mint(user, tokenId);
        levels[user][tokenId] = level;
        tokenId++;
    }
}
