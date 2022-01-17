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
import "./Erc721NFTFeeDistributor.sol";

contract ERC721NFTMarket is
    ERC721Holder,
    Ownable,
    ReentrancyGuard,
    Erc721NFTFeeDistributor
{
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct Ask {
        address seller;
        address quoteToken;
        uint256 price;
    }

    struct BidEntry {
        address quoteToken;
        uint256 price;
    }

    address public immutable WETH;

    // nft => tokenId => ask
    mapping(address => mapping(uint256 => Ask)) public asks;
    // nft => tokenId => bidder=> bid
    mapping(address => mapping(uint256 => mapping(address => BidEntry)))
        public bids;


    event AskNew(
        address indexed _seller,
        address indexed _nft,
        uint256 _tokenId,
        address _quoteToken,
        uint256 _price
    );
    event AskCancel(
        address indexed _seller,
        address indexed _nft,
        uint256 _tokenId
    );
    event Trade(
        address indexed _seller,
        address indexed buyer,
        address indexed _nft,
        uint256 _tokenId,
        address _quoteToken,
        uint256 _price,
        uint256 _netPrice
    );
    event AcceptBid(
        address indexed _seller,
        address indexed bidder,
        address indexed _nft,
        uint256 _tokenId,
        address _quoteToken,
        uint256 _price,
        uint256 _netPrice
    );
    event Bid(
        address indexed bidder,
        address indexed _nft,
        uint256 _tokenId,
        address _quoteToken,
        uint256 _price
    );
    event CancelBid(
        address indexed bidder,
        address indexed _nft,
        uint256 _tokenId
    );

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
     * @notice Create ask order
     * @param _nft: contract address of the NFT
     * @param _tokenId: tokenId of the NFT
     * @param _quoteToken: quote token
     * @param _price: price for listing (in wei)
     */
    function createAsk(
        address _nft,
        uint256 _tokenId,
        address _quoteToken,
        uint256 _price
    ) external nonReentrant notContract{
        // Verify price is not too low/high
        require(_price > 0, "Ask: Price must be granter than zero");
        IERC721(_nft).safeTransferFrom(
            address(msg.sender),
            address(this),
            _tokenId
        );
        asks[_nft][_tokenId] = Ask({
            seller: address(msg.sender),
            quoteToken: _quoteToken,
            price: _price
        });
        emit AskNew(address(msg.sender), _nft, _tokenId, _quoteToken, _price);
    }

    /**
     * @notice Cancel Ask
     * @param _nft: contract address of the NFT
     * @param _tokenId: tokenId of the NFT
     */
    function cancelAsk(address _nft, uint256 _tokenId) external nonReentrant {
        // Verify the sender has listed it
        require(
            asks[_nft][_tokenId].seller == msg.sender,
            "Ask: Token not listed"
        );
        IERC721(_nft).safeTransferFrom(
            address(this),
            address(msg.sender),
            _tokenId
        );
        delete asks[_nft][_tokenId];
        emit AskCancel(msg.sender, _nft, _tokenId);
    }

    /**
     * @notice Buy
     * @param _nft: contract address of the NFT
     * @param _tokenId: tokenId of the NFT
     * @param _quoteToken: quote token
     * @param _price: price for listing (in wei)
     */
    function buy(
        address _nft,
        uint256 _tokenId,
        address _quoteToken,
        uint256 _price
    ) external notContract{
        require(asks[_nft][_tokenId].seller!= address(0), "token is not sell");

        IERC20(_quoteToken).safeTransferFrom(
            address(msg.sender),
            address(this),
            _price
        );
        _buy(_nft, _tokenId, _quoteToken, _price);
    }

    function _buy(
        address _nft,
        uint256 _tokenId,
        address _quoteToken,
        uint256 _price
    ) private {
        Ask memory ask = asks[_nft][_tokenId];

        require(ask.quoteToken == _quoteToken, "Buy: Incorrect qoute token");
        require(ask.price == _price, "Buy: Incorrect price");
        uint256 fees = _distributeFees(_nft, _tokenId, _quoteToken, _price);
        uint256 netPrice = _price.sub(fees);
        IERC20(_quoteToken).safeTransfer(ask.seller, netPrice);
        IERC721(_nft).safeTransferFrom(
            address(this),
            address(msg.sender),
            _tokenId
        );
        delete asks[_nft][_tokenId];
        emit Trade(
            ask.seller,
            msg.sender,
            _nft,
            _tokenId,
            _quoteToken,
            _price,
            netPrice
        );
    }

    /**
     * @notice Buy using eth
     * @param _nft: contract address of the NFT
     * @param _tokenId: tokenId of the NFT
     */
    function buyUsingEth(address _nft, uint256 _tokenId)
        external
        payable
        nonReentrant
        notContract
    {
        require(asks[_nft][_tokenId].seller!= address(0), "token is not sell");
        IWETH(WETH).deposit{value: msg.value}();
        _buy(_nft, _tokenId, WETH, msg.value);
    }

    /**
     * @notice Create a offer
     * @param _nft: contract address of the NFT
     * @param _tokenId: tokenId of the NFT
     * @param _bidder: address of bidder
     * @param _quoteToken: quote token
     * @param _price: price for listing (in wei)
     */
    function acceptBid(
        address _nft,
        uint256 _tokenId,
        address _bidder,
        address _quoteToken,
        uint256 _price
    ) external {
        BidEntry memory bid = bids[_nft][_tokenId][_bidder];
        require(bid.price == _price, "AcceptBid: invalid price");
        require(bid.quoteToken == _quoteToken, "AcceptBid: invalid quoteToken");
        address seller = asks[_nft][_tokenId].seller;
        if (seller == msg.sender) {
            IERC721(_nft).safeTransferFrom(address(this), _bidder, _tokenId);
        } else {
            seller = address(msg.sender);
            IERC721(_nft).safeTransferFrom(seller, _bidder, _tokenId);
        }

        uint256 fees = _distributeFees(_nft, _tokenId, _quoteToken, _price);
        uint256 netPrice = _price.sub(fees);
        IERC20(_quoteToken).safeTransfer(seller, netPrice);

        delete asks[_nft][_tokenId];
        delete bids[_nft][_tokenId][_bidder];
        emit AcceptBid(
            seller,
            _bidder,
            _nft,
            _tokenId,
            _quoteToken,
            _price,
            netPrice
        );
    }

    function createBid(
        address _nft,
        uint256 _tokenId,
        address _quoteToken,
        uint256 _price
    ) external notContract {
        IERC20(_quoteToken).safeTransferFrom(
            address(msg.sender),
            address(this),
            _price
        );
        _createBid(_nft, _tokenId, _quoteToken, _price);
    }

    function _createBid(
        address _nft,
        uint256 _tokenId,
        address _quoteToken,
        uint256 _price
    ) private {
        require(_price > 0, "Bid: Price must be granter than zero");
        if (bids[_nft][_tokenId][msg.sender].price > 0) {
            // cancel old bid
            _cancelBid(_nft, _tokenId);
        }
        bids[_nft][_tokenId][msg.sender] = BidEntry({
            price: _price,
            quoteToken: _quoteToken
        });
        emit Bid(msg.sender, _nft, _tokenId, _quoteToken, _price);
    }

    function createBidUsingEth(address _nft, uint256 _tokenId)
        external
        payable
        notContract
        nonReentrant
    {
        IWETH(WETH).deposit{value: msg.value}();
        _createBid(_nft, _tokenId, WETH, msg.value);
    }

    function cancelBid(address _nft, uint256 _tokenId) external nonReentrant {
        _cancelBid(_nft, _tokenId);
    }

    function _cancelBid(address _nft, uint256 _tokenId) private {
        BidEntry memory bid = bids[_nft][_tokenId][msg.sender];
        require(bid.price > 0, "Bid: bid not found");
        IERC20(bid.quoteToken).safeTransfer(address(msg.sender), bid.price);
        delete bids[_nft][_tokenId][msg.sender];
        emit CancelBid(msg.sender, _nft, _tokenId);
    }

    function _isContract(address _addr) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(_addr)
        }
        return size > 0;
    }
}
