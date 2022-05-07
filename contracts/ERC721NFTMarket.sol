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
import "./ERC721NFTFeeDistributor.sol";
import "./ERC721Fingerprint.sol";

contract ERC721NFTMarket is
    ERC721Holder,
    Ownable,
    ReentrancyGuard,
    ERC721NFTFeeDistributor,
    ERC721Fingerprint
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
        bytes32 fingerprint;
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
        address _feeRecipient,
        uint256 _feePercent
    ) ERC721NFTFeeDistributor(_feeRecipient, _feePercent) {
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
    ) external nonReentrant notContract {
        // Verify price is not too low/high
        require(_price > 0, "Ask: Price must be greater than zero");
        IERC721(_nft).safeTransferFrom(_msgSender(), address(this), _tokenId);
        asks[_nft][_tokenId] = Ask({
            seller: _msgSender(),
            quoteToken: _quoteToken,
            price: _price
        });
        emit AskNew(_msgSender(), _nft, _tokenId, _quoteToken, _price);
    }

    /**
     * @notice Cancel Ask
     * @param _nft: contract address of the NFT
     * @param _tokenId: tokenId of the NFT
     */
    function cancelAsk(address _nft, uint256 _tokenId) external nonReentrant {
        // Verify the sender has listed it
        require(
            asks[_nft][_tokenId].seller == _msgSender(),
            "Ask: only seller"
        );
        IERC721(_nft).safeTransferFrom(address(this), _msgSender(), _tokenId);
        delete asks[_nft][_tokenId];
        emit AskCancel(_msgSender(), _nft, _tokenId);
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
        uint256 _price,
        bytes32 _fingeprint
    ) external notContract nonReentrant {
        require(asks[_nft][_tokenId].seller != address(0), "token is not sell");
        IERC20(_quoteToken).safeTransferFrom(
            _msgSender(),
            address(this),
            _price
        );
        _buy(_nft, _tokenId, _quoteToken, _price, _fingeprint);
    }

    function _buy(
        address _nft,
        uint256 _tokenId,
        address _quoteToken,
        uint256 _price,
        bytes32 _fingeprint
    ) private {
        Ask memory ask = asks[_nft][_tokenId];

        require(ask.quoteToken == _quoteToken, "Buy: Incorrect qoute token");
        require(ask.price == _price, "Buy: Incorrect price");
        _validateFingerprint(_nft, _tokenId, _fingeprint);
        uint256 fees = _distributeFees(_nft, _quoteToken, _price);
        uint256 netPrice = _price.sub(fees);
        IERC20(_quoteToken).safeTransfer(ask.seller, netPrice);
        IERC721(_nft).safeTransferFrom(address(this), _msgSender(), _tokenId);
        delete asks[_nft][_tokenId];
        emit Trade(
            ask.seller,
            _msgSender(),
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
    function buyUsingEth(
        address _nft,
        uint256 _tokenId,
        bytes32 _fingerprint
    ) external payable nonReentrant notContract {
        require(asks[_nft][_tokenId].seller != address(0), "token is not sell");
        IWETH(WETH).deposit{value: msg.value}();
        _buy(_nft, _tokenId, WETH, msg.value, _fingerprint);
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
    ) external nonReentrant {
        BidEntry memory bid = bids[_nft][_tokenId][_bidder];
        require(bid.price == _price, "AcceptBid: invalid price");
        require(bid.quoteToken == _quoteToken, "AcceptBid: invalid quoteToken");
        _validateFingerprint(_nft, _tokenId, bid.fingerprint);

        address seller = asks[_nft][_tokenId].seller;
        if (seller == _msgSender()) {
            IERC721(_nft).safeTransferFrom(address(this), _bidder, _tokenId);
        } else {
            seller = _msgSender();
            IERC721(_nft).safeTransferFrom(seller, _bidder, _tokenId);
        }

        uint256 fees = _distributeFees(_nft, _quoteToken, _price);
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
        uint256 _price,
        bytes32 _fingerprint
    ) external notContract nonReentrant {
        IERC20(_quoteToken).safeTransferFrom(
            _msgSender(),
            address(this),
            _price
        );
        _createBid(_nft, _tokenId, _quoteToken, _price, _fingerprint);
    }

    function _createBid(
        address _nft,
        uint256 _tokenId,
        address _quoteToken,
        uint256 _price,
        bytes32 _fingerprint
    ) private {
        require(_price > 0, "Bid: Price must be granter than zero");
        if (bids[_nft][_tokenId][_msgSender()].price > 0) {
            // cancel old bid
            _cancelBid(_nft, _tokenId);
        }
        bids[_nft][_tokenId][_msgSender()] = BidEntry({
            price: _price,
            quoteToken: _quoteToken,
            fingerprint: _fingerprint
        });
        emit Bid(_msgSender(), _nft, _tokenId, _quoteToken, _price);
    }

    function createBidUsingEth(
        address _nft,
        uint256 _tokenId,
        bytes32 _fingperprint
    ) external payable notContract nonReentrant {
        IWETH(WETH).deposit{value: msg.value}();
        _createBid(_nft, _tokenId, WETH, msg.value, _fingperprint);
    }

    function cancelBid(address _nft, uint256 _tokenId) external nonReentrant {
        _cancelBid(_nft, _tokenId);
    }

    function _cancelBid(address _nft, uint256 _tokenId) private {
        BidEntry memory bid = bids[_nft][_tokenId][_msgSender()];
        require(bid.price > 0, "Bid: bid not found");
        IERC20(bid.quoteToken).safeTransfer(_msgSender(), bid.price);
        delete bids[_nft][_tokenId][_msgSender()];
        emit CancelBid(_msgSender(), _nft, _tokenId);
    }

    function _isContract(address _addr) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(_addr)
        }
        return size > 0;
    }
}
