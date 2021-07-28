// SPDX-License-Identifier: MIT

pragma solidity =0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "../libraries/TransferHelper.sol";


contract ArtworkNFT is ERC721URIStorage, Ownable {
    uint256 public nextTokenId = 1;
    uint256 MAX_ROYALTIES = 10000;
    address public mintFeeAddr;
    uint256 public mintFeeAmount;
    mapping(uint256 => Profile) public profiles;
    
    struct Profile {
        address creator;
        uint256 royalties;
    }
    
    event UpdatedProfile(uint256 tokenId, address creator, uint256 royalties);
    
    constructor(string memory _name, string memory _symbol, address _mintFeeAddr, uint256 _mintFeeAmount) ERC721(_name, _symbol) Ownable() {
       mintFeeAddr = _mintFeeAddr;
       mintFeeAmount = _mintFeeAmount;
    }
    
    function setProfile(uint256 tokenId, address _creator, uint256 _royalties) public {
        require(profiles[tokenId].creator == _msgSender(), "only creator");
        require(_msgSender() != _creator, "yourself");
        require(_royalties <= MAX_ROYALTIES, "max royalties");
        _setProfile(tokenId, _creator, _royalties);
    }
    
    function _setProfile(uint256 tokenId, address _creator, uint256 _royalties) private {
        profiles[tokenId].creator = _creator;
        profiles[tokenId].royalties = _royalties;
        emit UpdatedProfile(tokenId, _creator, _royalties);
    }
  
    
    function mint(address _to, string memory _tokenURI, uint256 _royalties) public payable returns (uint256 tokenId) {
        require(msg.value >= mintFeeAmount, 'msg value too low');
        TransferHelper.safeTransferETH(mintFeeAddr, mintFeeAmount);
        tokenId = nextTokenId;
        _mint(_to, tokenId);
        nextTokenId++;
        _setProfile(tokenId, _msgSender(), _royalties);
        _setTokenURI(tokenId, _tokenURI);
        if (msg.value > mintFeeAmount) TransferHelper.safeTransferETH(msg.sender, msg.value - mintFeeAmount);
    }
    
    /**
     * @dev Burns `tokenId`. See {ERC721-_burn}.
     *
     * Requirements:
     *
     * - The caller must own `tokenId` or be an approved operator.
     */
    function burn(uint256 tokenId) public virtual {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721Burnable: caller is not owner nor approved");
        _burn(tokenId);
        delete profiles[tokenId];
    }
    
    function setMintFeeAddr(address _mintFeeAddr) public onlyOwner {
        mintFeeAddr = _mintFeeAddr;
    }
    
    function setMintFeeAmount(uint256 _mintFeeAmount) public onlyOwner {
        mintFeeAmount = _mintFeeAmount;
    }
}