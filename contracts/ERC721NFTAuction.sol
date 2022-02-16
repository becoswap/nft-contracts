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
import "./Erc721NFTFeeDistributor.sol";

contract ERC721NFTAuction is
    ERC721Holder,
    Ownable,
    ReentrancyGuard,
    Erc721NFTFeeDistributor
{
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public immutable WETH;

    struct Auction {
        uint256 bidPrice; // bid price
        address seller; // address of the seller
        address bidder; // address of bidder
        uint256 startTime; // start time of the auction
        uint256 endTime; // end time of the auction
        address quoteToken; // quote token of the acution
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

    event CancelAuction(address indexed nft, uint256 tokenId);

    event Bid(
        address indexed nft,
        address indexed bidder,
        uint256 tokenId,
        uint256 price
    );

    event AuctionCompleted(
        address indexed nft,
        uint256 tokenId,
        address seller,
        address buyer,
        uint256 price,
        uint256 netPrice
    );

    mapping(address => mapping(uint256 => Auction)) public auctions;

    // The minimum percentage difference between the last bid amount and the current bid.
    uint8 public minBidIncrementPercentage = 5;

    modifier notContract() {
        require(!_isContract(msg.sender), "Contract not allowed");
        require(msg.sender == tx.origin, "Proxy contract not allowed");
        _;
    }

    constructor(
        address _weth,
        address _feeProvider,
        address _feeRecipient,
        uint256 _feePercent
    ) Erc721NFTFeeDistributor(_feeProvider, _feeRecipient, _feePercent) {
        WETH = _weth;
    }

    /**
     * @notice Create Auction
     * @param _nft: contract address of the NFT
     * @param _tokenId: tokenId of the NFT
     * @param _quoteToken: quote token
     * @param _price: price for auction (in wei)
     * @param _startTime: start time for auction (timestamp)
     * @param _endTime: end time for auction (timestamp)
     */
    function createAuction(
        address _nft,
        uint256 _tokenId,
        address _quoteToken,
        uint256 _price,
        uint256 _startTime,
        uint256 _endTime
    ) external notContract  nonReentrant{
        require(
            _endTime > block.timestamp,
            "ERC721NFTAuction: _endTime must be greater than block.timestamp"
        );
        require(
            _endTime > _startTime,
            "ERC721NFTAuction: _endTime must be greater than _startTime"
        );
        IERC721(_nft).safeTransferFrom(
            address(msg.sender),
            address(this),
            _tokenId
        );
        auctions[_nft][_tokenId] = Auction({
            bidPrice: _price,
            bidder: address(0),
            seller: address(msg.sender),
            startTime: _startTime,
            endTime: _endTime,
            quoteToken: _quoteToken
        });
        emit AuctionCreated(
            _nft,
            msg.sender,
            _tokenId,
            _startTime,
            _endTime,
            _quoteToken,
            _price
        );
    }

    /**
     * @notice Cancel Auction
     * @param _nft: contract address of the NFT
     * @param _tokenId: tokenId of the NFT
     */
    function cancelAuction(address _nft, uint256 _tokenId) external nonReentrant{
        require(
            auctions[_nft][_tokenId].seller == msg.sender,
            "ERC721NFTAuction: only seller"
        );
        require(
            auctions[_nft][_tokenId].bidder == address(0),
            "ERC721NFTAuction: has bidder"
        );
        IERC721(_nft).safeTransferFrom(
            address(this),
            address(msg.sender),
            _tokenId
        );
        delete auctions[_nft][_tokenId];
        emit CancelAuction(_nft, _tokenId);
    }

    /**
     * @notice Bid Auction
     * @param _nft: contract address of the NFT
     * @param _tokenId: tokenId of the NFT
     * @param _price: price of Bid
     * @param _quoteToken: quote token of auction
     */
    function bid(
        address _nft,
        uint256 _tokenId,
        address _quoteToken,
        uint256 _price
    ) external payable notContract nonReentrant{
        Auction storage auction = auctions[_nft][_tokenId];
        require(
            auction.seller != address(0),
            "ERC721NFTAuction: auction not found"
        );
        require(
            auction.startTime <= block.timestamp,
            "ERC721NFTAuction: auction not started"
        );
        require(
            auction.endTime > block.timestamp,
            "ERC721NFTAuction: auction ended"
        );

        if (auction.bidder != address(0)) {
            require(
                _price >=
                    auction.bidPrice.add(
                        auction.bidPrice.mul(minBidIncrementPercentage).div(100)
                    ),
                "ERC721NFTAuction: price must be greater than bidPrice with minBidIncrementPercentage"
            );
        } else {
            require(
                _price >= auction.bidPrice,
                "ERC721NFTAuction: price must be greater than or equal bidPrice"
            );
        }

        require(
            auction.quoteToken == _quoteToken,
            "ERC721NFTAuction: invalid quote token"
        );

        if (auction.quoteToken == WETH && msg.value == _price) {
            IWETH(WETH).deposit{value: _price}();
        } else {
            IERC20(auction.quoteToken).safeTransferFrom(
                address(msg.sender),
                address(this),
                _price
            );
        }

        if (auction.bidder != address(0)) {
            IERC20(auction.quoteToken).safeTransfer(
                auction.bidder,
                auction.bidPrice
            );
        }

        auction.bidder = address(msg.sender);
        auction.bidPrice = _price;
        emit Bid(_nft, auction.bidder, _tokenId, _price);
    }

    /**
     * @notice Collect NFT
     * @param _nft: contract address of the NFT
     * @param _tokenId: tokenId of the NFT
     */
    function collect(address _nft, uint256 _tokenId) external nonReentrant{
        Auction memory auction = auctions[_nft][_tokenId];
        require(
            auction.endTime < block.timestamp,
            "ERC721NFTAuction: auction not end"
        );
        IERC721(_nft).safeTransferFrom(address(this), auction.bidder, _tokenId);
        uint256 fees = _distributeFees(
            _nft,
            _tokenId,
            auction.quoteToken,
            auction.bidPrice
        );
        uint256 netPrice = auction.bidPrice.sub(fees);
        IERC20(auction.quoteToken).safeTransfer(auction.seller, netPrice);
        delete auctions[_nft][_tokenId];
        emit AuctionCompleted(
            _nft,
            _tokenId,
            auction.seller,
            auction.bidder,
            auction.bidPrice,
            netPrice
        );
    }

    function _isContract(address _addr) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(_addr)
        }
        return size > 0;
    }
}
