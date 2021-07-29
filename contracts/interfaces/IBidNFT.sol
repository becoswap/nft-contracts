// SPDX-License-Identifier: MIT

pragma solidity >=0.6.2;


interface IBidNFT {
    function buyToken(uint256 _tokenId) external;

    function buyTokenTo(uint256 _tokenId, address _to) external;

    function setCurrentPrice(uint256 _tokenId, uint256 _price) external;

    function readyToSellToken(uint256 _tokenId, uint256 _price) external;

    function readyToSellTokenTo(
        uint256 _tokenId,
        uint256 _price,
        address _to
    ) external;

    function cancelSellToken(uint256 _tokenId) external;

    function bidToken(uint256 _tokenId, uint256 _price) external;


    function sellTokenTo(uint256 _tokenId, address _to) external;

    function cancelBidToken(uint256 _tokenId) external;
}