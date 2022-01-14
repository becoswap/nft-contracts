

// SPDX-License-Identifier: MIT
pragma solidity =0.8.0;



contract TestFeeProvider {
    address[] public recipients;
    uint256[] public rates;



    function getFees(uint256 nftId) public view returns (address[] memory, uint256[] memory){
        return (recipients, rates);
    }
}