// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma abicoder v2;

import "./interfaces/IERC721Fingerprint.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ERC721Fingerprint is Ownable {
    mapping(address => address) public fingerprintProxies;

    event FingerprintProxyRegisted(address _nft, address _fingerprintProxy);

    function registerFingerPrintProxy(address _nft, address _fingerprintProxy)
        external
        onlyOwner
    {
        fingerprintProxies[_nft] = _fingerprintProxy;
        emit FingerprintProxyRegisted(_nft, _fingerprintProxy);
    }

    function _validateFingerprint(
        address _nft,
        uint256 _tokenId,
        bytes32 _fingerprint
    ) internal view {
        if (fingerprintProxies[_nft] != address(0)) {
            require(
                IERC721Fingerprint(fingerprintProxies[_nft]).verifyFingerprint(
                    _tokenId,
                    _fingerprint
                ),
                "Erc721Fingerprint: invalid fingerprint"
            );
        }
    }
}
