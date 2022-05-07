// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract TestErc721 is ERC721 {
    constructor() ERC721("DEMO", "DEMO") {

  }
    function mint(uint256 _tokenId) public {
        _mint(msg.sender, _tokenId);
    }
}
