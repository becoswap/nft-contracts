// SPDX-License-Identifier: MIT

pragma solidity >=0.5.0;

interface IFeeProvider {
    function getFees(uint256 nftId) external returns (address[] memory addrs, uint256[] memory rates);
}