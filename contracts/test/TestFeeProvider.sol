

// SPDX-License-Identifier: MIT
pragma solidity =0.8.0;



contract TestFeeProvider {
    address[] public recipients;
    uint256[] public rates;

    function setRecipient(address[] calldata _recipients, uint256[] calldata _rates) external {
        recipients = _recipients;
        rates = _rates;
    }

    function getFees(uint256 nftId) public view returns (address[] memory, uint256[] memory){
        return (recipients, rates);
    }
}