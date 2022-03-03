// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;
pragma abicoder v2;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

contract ERC721NFTSingleBundle is ERC721, ERC721Holder {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    address public nft;
    mapping(uint256 => uint256[]) _bundles;

    event BundleNew(uint256 tokenId, uint256[] tokenIds);
    event BundleAdd(uint256 tokenId, uint256[] tokenIds);
    event BundleRemove(uint256 tokenId, uint256[] tokenIds);

    constructor(
        address _nft,
        string memory _name,
        string memory _symbol
    ) ERC721(_name, _symbol) {
        nft = _nft;
    }

    /**
     * @notice create bundle
     * @param tokenIds: id of tokens
     */
    function createBundle(uint256[] memory tokenIds)
        external
        returns (uint256)
    {
        _tokenIds.increment();
        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            IERC721(nft).safeTransferFrom(_msgSender(), address(this), tokenId);
        }
        _bundles[_tokenIds.current()] = tokenIds;
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
            "ERC721NFTSingleBundle: caller is not owner nor approved"
        );
        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            IERC721(nft).safeTransferFrom(_msgSender(), address(this), tokenId);
            _bundles[bundleId].push(tokenId);
        }
        emit BundleAdd(bundleId, tokenIds);
    }

    function _removeItem(uint256 bundleId, uint256 tokenId)
        private
        returns (bool)
    {
        for (uint256 i = 0; i < _bundles[bundleId].length; i++) {
            if (_bundles[bundleId][i] == tokenId) {
                uint256 lastIndex = _bundles[bundleId].length - 1;
                _bundles[bundleId][i] = _bundles[bundleId][lastIndex];
                _bundles[bundleId].pop();
                IERC721(nft).safeTransferFrom(
                    address(this),
                    _msgSender(),
                    tokenId
                );
                return true;
            }
        }
        return false;
    }

    /**
     * @notice remove items
     * @param bundleId: id of bundle
     * @param tokenIds: index
     */
    function removeItems(uint256 bundleId, uint256[] memory tokenIds) external {
        require(
            _isApprovedOrOwner(_msgSender(), bundleId),
            "ERC721NFTSingleBundle: caller is not owner nor approved"
        );
        for (uint256 i = 0; i < tokenIds.length; i++) {
            bool removed = _removeItem(bundleId, tokenIds[i]);
            require(removed, "ERC721NFTSingleBundle: not removed");
        }
        if (_bundles[bundleId].length == 0) {
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
            "ERC721NFTSingleBundle: caller is not owner nor approved"
        );
        for (uint256 i = 0; i < _bundles[bundleId].length; i++) {
            uint256 tokenId = _bundles[bundleId][i];
            IERC721(nft).safeTransferFrom(address(this), _msgSender(), tokenId);
        }
        delete _bundles[bundleId];
        _burn(bundleId);
    }

    function getBundleItems(
        uint256 bundleId
    ) external view returns (uint256[] memory) {
        return _bundles[bundleId];
    }

    function bundleItemLength(uint256 bundleId)
        external
        view
        returns (uint256)
    {
        return _bundles[bundleId].length;
    }

    /**
     * @dev Creates a checksum of the contents of the Bundle
     * @param bundleId the bundleId to be verified
     */
    function getFingerprint(uint256 bundleId)
        public
        view
        returns (bytes32 result)
    {
        result = keccak256(abi.encodePacked("bundleId", bundleId));

        uint256 length = _bundles[bundleId].length;
        for (uint256 i = 0; i < length; i++) {
            result ^= keccak256(abi.encodePacked(_bundles[bundleId][i]));
        }
        return result;
    }

    /**
     * @dev Verifies a checksum of the contents of the Bundle
     * @param bundleId the bundleId to be verified
     * @param fingerprint the user provided identification of the Bundle contents
     */
    function verifyFingerprint(uint256 bundleId, bytes32 fingerprint)
        public
        view
        returns (bool)
    {
        return getFingerprint(bundleId) == fingerprint;
    }
}
