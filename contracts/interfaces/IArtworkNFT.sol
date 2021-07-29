// SPDX-License-Identifier: MIT

pragma solidity >=0.6.2;
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IArtworkNFT is IERC721{
  function profiles(uint256 tokenId) public view returns (address, uint256);
}