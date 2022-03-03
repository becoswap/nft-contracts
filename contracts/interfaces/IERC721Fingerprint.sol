// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

interface IERC721Fingerprint {
    function verifyFingerprint(uint256 estateId, bytes32 fingerprint) external view returns (bool);
}