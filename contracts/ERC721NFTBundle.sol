// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;
pragma abicoder v2;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";


contract ERC721NFTBundle is ERC721, ERC721Holder,Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    mapping(uint256 => string) public metadata;

    struct Group {
        address nft;
        uint256[] tokenIds;
    }

    string public baseURI;
    mapping(uint256 => Group[]) private _bundles;

    event CreatedBundle(uint256 tokenId, Group[] groups);
    event BundleAdd(uint256 tokenId, Group[] groups);
    event BundleRemove(uint256 tokenId, Group[] groups);
    event MetadataUpdate(uint256 tokenId, string data);

    constructor() ERC721("BecoNFTBundle", "BNU") {}

    function updateMetdata(uint256 bundleId, string memory data) external {
        require(
            _isApprovedOrOwner(_msgSender(), bundleId),
            "ERC721NFTBundle: caller is not owner nor approved"
        );
        metadata[bundleId] = data;
        emit MetadataUpdate(bundleId, data);
    }

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
            _bundles[_tokenIds.current()].push(
                Group({nft: _groups[i].nft, tokenIds: _groups[i].tokenIds})
            );
        }
        _safeMint(_msgSender(), _tokenIds.current());
        emit CreatedBundle(_tokenIds.current(), _bundles[_tokenIds.current()]);
        return _tokenIds.current();
    }

    function addBundleItems(uint256 bundleId, Group[] memory _groups) external {
        require(
            _isApprovedOrOwner(_msgSender(), bundleId),
            "ERC721NFTBundle: caller is not owner nor approved"
        );

        for (uint256 i = 0; i < _groups.length; i++) {
            _addBundleGroup(bundleId, _groups[i]);
        }
        emit BundleAdd(bundleId, _groups);
    }

    function _addBundleGroup(uint256 bundleId, Group memory _group) private {
        bool added;
        for (uint256 i = 0; i < _bundles[bundleId].length; i++) {
            if (_bundles[bundleId][i].nft == _group.nft) {
                for (uint256 j = 0; j < _group.tokenIds.length; j++) {
                    uint256 tokenId = _group.tokenIds[j];
                    IERC721(_group.nft).safeTransferFrom(
                        _msgSender(),
                        address(this),
                        tokenId
                    );
                    _bundles[bundleId][i].tokenIds.push(tokenId);
                    added = true;
                }
            }
        }
        require(added, "ERC721NFTBundle: not added");
    }

    function removeBundleItems(uint256 bundleId, Group[] memory _groups)
        external
    {
        require(
            _isApprovedOrOwner(_msgSender(), bundleId),
            "ERC721NFTBundle: caller is not owner nor approved"
        );

        for (uint256 i = 0; i < _groups.length; i++) {
            _removeBundleGroup(bundleId, _groups[i]);
        }

        uint256 totalTokens;
        for (uint256 i = 0; i < _bundles[bundleId].length; i++) {
            totalTokens += _bundles[bundleId][i].tokenIds.length;
        }

        if (totalTokens == 0) {
            delete _bundles[bundleId];
            delete metadata[bundleId];
            _burn(bundleId);
        } else {
            emit BundleRemove(bundleId, _groups);
        }
    }

    function _removeBundleGroup(uint256 bundleId, Group memory _group) private {
        uint256 removeCount;
        for (uint256 i = 0; i < _bundles[bundleId].length; i++) {
            if (_bundles[bundleId][i].nft == _group.nft) {
                for (uint256 j = 0; j < _group.tokenIds.length; j++) {
                    for (
                        uint256 jj = 0;
                        jj < _bundles[bundleId][i].tokenIds.length;
                        jj++
                    ) {
                        uint256 tokenId = _group.tokenIds[j];
                        if (_bundles[bundleId][i].tokenIds[jj] == tokenId) {
                            uint256 lastIndex = _bundles[bundleId][i]
                                .tokenIds
                                .length - 1;
                            _bundles[bundleId][i].tokenIds[jj] = _bundles[
                                bundleId
                            ][i].tokenIds[lastIndex];
                            _bundles[bundleId][i].tokenIds.pop();
                            IERC721(_group.nft).safeTransferFrom(
                                address(this),
                                _msgSender(),
                                tokenId
                            );
                            removeCount++;
                        }
                    }
                }
            }
        }
        require(
            removeCount == _group.tokenIds.length,
            "ERC721NFTBundle: not removed"
        );
    }

    function removeBundle(uint256 bundleId) external {
        require(
            _isApprovedOrOwner(_msgSender(), bundleId),
            "ERC721NFTBundle: caller is not owner nor approved"
        );
        for (uint256 i = 0; i < _bundles[bundleId].length; i++) {
            for (
                uint256 j = 0;
                j < _bundles[bundleId][i].tokenIds.length;
                j++
            ) {
                IERC721(_bundles[bundleId][i].nft).safeTransferFrom(
                    address(this),
                    _msgSender(),
                    _bundles[bundleId][i].tokenIds[j]
                );
            }
        }
        delete _bundles[bundleId];
        delete metadata[bundleId];
        _burn(bundleId);
    }

    function getBundle(uint256 bundleId)
        external
        view
        returns (Group[] memory)
    {
        return _bundles[bundleId];
    }

    function setBaseURI(string calldata _baseURI) external onlyOwner {
        baseURI = _baseURI;
    }

    /**
     * @notice Returns an URI for a given token ID.
     * Throws if the token ID does not exist. May return an empty string.
     * @param _tokenId - uint256 ID of the token queried
     * @return token URI
     */
    function tokenURI(uint256 _tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(_exists(_tokenId), "tokenURI: INVALID_TOKEN_ID");
        return string(abi.encodePacked(baseURI, Strings.toString(_tokenId)));
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
            result ^= keccak256(abi.encodePacked(_bundles[bundleId][i].nft));
            for (
                uint256 j = 0;
                j < _bundles[bundleId][i].tokenIds.length;
                j++
            ) {
                uint256 tokenId = _bundles[bundleId][i].tokenIds[j];
                result ^= keccak256(abi.encodePacked(tokenId));
            }
        }
        return result;
    }

    /**
     * @dev Verifies a checksum of the contents of the Bundle
     * @param bundleId the bundleId to be verified
     * @param fingerprint the user provided identification of the Estate contents
     */
    function verifyFingerprint(uint256 bundleId, bytes32 fingerprint)
        public
        view
        returns (bool)
    {
        return getFingerprint(bundleId) == fingerprint;
    }
}
