// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract TestErc1155 is ERC1155 {
    constructor() ERC1155("domain.com") {}

    function mint(uint256 _tokenId, uint256 _amount) public {
        _mint(msg.sender, _tokenId, _amount, "");
    }
}
