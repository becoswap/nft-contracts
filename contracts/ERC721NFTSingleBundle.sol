// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;
pragma abicoder v2;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract ERC721NFTSingleBundle is ERC721, ERC721Holder {
    using EnumerableSet for EnumerableSet.UintSet;
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    address public nft;
    mapping(uint256 => EnumerableSet.UintSet) _bundles;

    event BundleNew(uint256 tokenId, uint256[] tokenIds);
    event BundleAdd(uint256 tokenId, uint256[] tokenIds);
    event BundleRemove(uint256 tokenId, uint256[] tokenIds);

    constructor(string memory _name, string memory _symbol)
        public
        ERC721(_name, _symbol)
    {}

    /**
     * @notice create bundle
     * @param tokenIds: id of tokens
     */
    function createBundle(uint256[] tokenIds) external returns (uint256) {
        _tokenIds.increment();
        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            IERC721(nft).safeTransferFrom(_msgSender(), address(this), tokenId);
            _bundles[_tokenIds.current()].add(tokenId);
        }

        _safeMint(_msgSender(), _tokenIds.current());
        emit BundleNew(_tokenIds.current(), tokenIds);
        return _tokenIds.current();
    }

    /**
     * @notice add items
     * @param bundleId: id of bundle
     * @param tokenIds: id of tokens
     */
    function addItems(uint256 bundleId, uint256[] memory tokenIds) external {
        require(
            _isApprovedOrOwner(_msgSender(), bundleId),
            "ERC721Burnable: caller is not owner nor approved"
        );
        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            IERC721(nft).safeTransferFrom(_msgSender(), address(this), tokenId);
            _bundles[bundleId].add(tokenId);
        }
        emit BundleAdd(bundleId, tokenIds);
    }

    /**
     * @notice remove items
     * @param bundleId: id of bundle
     * @param tokenIds: id of tokens
     */
    function removeItems(uint256 bundleId, uint256[] memory tokenIds) external {
        require(
            _isApprovedOrOwner(_msgSender(), bundleId),
            "ERC721Burnable: caller is not owner nor approved"
        );
        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            require(_bundles[bundleId].has(tokenId), "invalid token id");
            _bundles[bundleId].remove(tokenId);
            IERC721(nft).safeTransferFrom(address(this), _msgSender(), tokenId);
        }
        if (_bundles[bundleId].length() == 0) {
            _burn(bundleId);
        } else {
            emit BundleRemove(bundleId, tokenIds);
        }
    }

    /**
     * @notice remove all items
     * @param bundleId: id of bundle
     */
    function removeAllItems(uint256 bundleId) external {
        require(
            _isApprovedOrOwner(_msgSender(), bundleId),
            "ERC721Burnable: caller is not owner nor approved"
        );
        for (uint256 i = 0; i < _bundles[bundleId].length(); i++) {
            uint256 tokenId = _bundles[bundleId].at(i);
            IERC721(nft).safeTransferFrom(address(this), _msgSender(), tokenId);
            _bundles[bundleId].remove(tokenId);
        }
        _burn(bundleId);
    }

    function getBundleItems(
        uint256 bundleId,
        uint256 start,
        uint256 end
    ) external view returns (uint256[] memory) {
        uint8[end - start] memory tokenIds;
        for (uint256 i = start; i < end; i++) {
            tokenIds.push(_bundles[bundleId].at(i));
        }
        return tokenIds;
    }

    function allBundleItemLength(uint256 bundleId) external returns (uint256) {
        return _bundles[bundleId].length();
    }
}
