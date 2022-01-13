// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma abicoder v2;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IWETH.sol";
import "./interfaces/IFeeProvider.sol";

contract ERC721NFTAuction is ERC721Holder, Ownable, ReentrancyGuard {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public WETH;


    struct Auction {
        uint256 askPrice;
        uint256 bidPrice;
        address seller;
        address bidder;
        uint256 startTime;
        uint256 endTime;
        address quoteToken;
    }

    event AuctionCreated(
        address indexed nft,
        address indexed seller,
        uint256 tokenId,
        uint256 startTime,
        uint256 endTime,
        address quoteToken,
        uint256 price
    );

    event CancelAuction(
        address indexed nft,
        uint256 tokenId
    );

    event Bid(
        address indexed nft,
        address indexed bidder,
        uint256 tokenId,
        uint256 price
    );

    event AuctionCompleted(
        address indexed nft,
        uint256 tokenId
    );

    mapping(address => mapping(uint => Auction)) public auctions;

    function createAuction(
        address _nft,
        uint256 _tokenId,
        address _quoteToken,
        uint256 _price,
        uint256 _startTime,
        uint256 _endTime
    ) external {
        require(block.timestamp >= _startTime, "ERC721NFTAuction: invalid start time");
        require(_endTime > _startTime, "ERC721NFTAuction: invalid end time");
        IERC721(_nft).safeTransferFrom(address(msg.sender), address(this), _tokenId);
        auctions[_nft][_tokenId] = Auction({
            bidPrice: 0,
            askPrice: _price,
            bidder: address(0),
            seller: address(msg.sender),
            startTime: _startTime,
            endTime: _endTime,
            quoteToken: _quoteToken
        });
        emit AuctionCreated(_nft, msg.sender, _tokenId, _startTime, _endTime, _quoteToken, _price);
    }


    function cancelAuction(
        address _nft,
        uint256 _tokenId
    ) external {
        require(auctions[_nft][_tokenId].seller == msg.sender, "ERC721NFTAuction: only seller can cancel");
        require(auctions[_nft][_tokenId].bidder == address(0), "ERC721NFTAuction: can not cancel");
        IERC721(_nft).safeTransferFrom(address(this), address(msg.sender), _tokenId);
        delete auctions[_nft][_tokenId];
        emit CancelAuction(_nft, _tokenId);
    }

    function bid(
        address _nft,
        uint256 _tokenId,
        uint256 _price
    ) external payable {
        Auction memory auction = auctions[_nft][_tokenId];
        require(auction.seller != address(0), "ERC721NFTAuction: auction not found");
        require(auction.startTime <= block.timestamp, "ERC721NFTAuction: start time");
        require(auction.endTime > block.timestamp, "ERC721NFTAuction: endtime");
        require(auction.bidPrice < _price, "ERC721NFTAuction: price");

        if (auction.quoteToken == WETH && msg.value == _price) {
            IWETH(WETH).deposit{value: amount}();
        } else {
            IERC20(auction.quoteToken).safeTransferFrom(address(msg.sender), address(this), _price);
        }

        // cancel old bidder
        if (auction.bidder != address(0)) {
            IERC20(auction.quoteToken).safeTransferFrom(address(this), auction.bidder, _price);
        }
        
        auction.bidder = address(msg.sender);
        auction.price = _price;
        emit Bid(_nft, auction.bidder, _tokenId, _price);
    }


    function collect(
        address _nft,
        uint256 _tokenId
    ) external {
        Auction memory auction = auctions[_nft][_tokenId];
        require(auction.endTime < block.timestamp, "ERC721NFTAuction: endtime");
        require(auction.askPrice >= auction.bidPrice, "ERC721NFTAuction: need seller accept");
        IERC721(_nft).safeTransferFrom(address(this), auction.bidder, _tokenId);
        IERC20(auction.quoteToken).safeTransferFrom(address(this), auction.seller, _price);
        delete auctions[_nft][_tokenId];
        emit AuctionCompleted(_nft);
    }

    function accept(
        address _nft,
        uint256 _tokenId
    ) {
        Auction memory auction = auctions[_nft][_tokenId];
        require(auction.seller == msg.sender, "ERC721NFTAuction: only seller");
        require(auction.endTime < block.timestamp, "ERC721NFTAuction: endtime");
        IERC721(_nft).safeTransferFrom(address(this), auction.bidder, _tokenId);
        IERC20(auction.quoteToken).safeTransferFrom(address(this), auction.seller, _price);
        delete auctions[_nft][_tokenId];
        emit AuctionCompleted(_nft, _tokenId);
    }
}
