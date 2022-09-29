// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

interface IERC721Operator {
    function setOperator(uint256 tokenId, address _operator) external;
}