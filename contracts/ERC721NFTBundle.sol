// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;
pragma abicoder v2;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

contract ERC721NFTBundle is ERC721, ERC721Holder{
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    struct Group {
        address nft;
        uint256[] tokenIds;
    }

    mapping(uint256 => Group[]) private _bundles;

    event CreatedBundle(uint256 tokenId,  Group[] groups);

    constructor() public ERC721("BecoNFTBundle", "BNU"){}

    function createBundle(Group[] memory _groups) external returns (uint256) {
        _tokenIds.increment();
        for (uint256 i = 0; i < _groups.length; i++) {
            for (uint256 j = 0; j < _groups[i].tokenIds.length; j++) {
                IERC721(_groups[i].nft).safeTransferFrom(
                    _msgSender(),
                    address(this),
                    _groups[i].tokenIds[j]
                );
            }
            _bundles[_tokenIds.current()].push(Group({
                nft: _groups[i].nft,
                tokenIds: _groups[i].tokenIds
            }));
        }
        _safeMint(_msgSender(), _tokenIds.current());
        emit CreatedBundle(_tokenIds.current(), _bundles[_tokenIds.current()]);
        return _tokenIds.current();
    }

    function removeBundle(uint256 bundleId) external {
        require(
            _isApprovedOrOwner(_msgSender(), bundleId),
            "ERC721Burnable: caller is not owner nor approved"
        );
        for (uint256 i = 0; i < _bundles[bundleId].length; i++) {
            for (uint256 j = 0; j < _bundles[bundleId][i].tokenIds.length; j++) {
                IERC721(_bundles[bundleId][i].nft).safeTransferFrom(
                    address(this),
                    _msgSender(),
                    _bundles[bundleId][i].tokenIds[j]
                );
            }
        }
        delete _bundles[bundleId];
        _burn(bundleId);
    }


    function getBundle(uint256 bundleId) external view returns (Group[] memory) {
        return _bundles[bundleId];
    }
}
