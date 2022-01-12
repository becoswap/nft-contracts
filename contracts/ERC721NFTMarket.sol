pragma solidity ^0.8.0;
pragma abicoder v2;

import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ERC721NFTMarket is ERC721Holder, Ownable, ReentrancyGuard {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;

    using SafeERC20 for IERC20;

    struct Ask {
        address seller;
        address quoteToken;
        uint256 price;
    }

    struct Bid {
        address quoteToken;
        uint256 price;
    }
    

    // nft => tokenId => ask
    mapping(address => mapping(uint => Ask)) public asks;
    // nft => tokenId => bidder=> bid
    mapping(address => mapping(uint => mapping(address => Bid))) public bids;

    event AskNew(address indexed _seller, address indexed _nft , uint256 _tokenId, address _quoteToken, uint256 _price);
    event AskCancel(address indexed _seller, address indexed _nft , uint256 _tokenId);
    event Trade(address indexed _seller, address indexed buyer, address indexed _nft, uint256 _tokenId, address _quoteToken, uint256 _price, uint256 _netPrice);
    event Bid(address indexed bidder, address indexed _nft, uint256 _tokenId, address _quoteToken, uint256 _price);
    event CancelBid(address indexed bidder, address indexed _nft, uint256 _tokenId);
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
    ) external nonReentrant {
        // Verify price is not too low/high
        require(_price > 0, "Ask: Price must be granter than zero");
        IERC721(_nft).safeTransferFrom(address(msg.sender), address(this), _tokenId);
        asks[_nft][_tokenId] = Ask({
            seller: address(msg.sender),
            quoteToken: _quoteToken,
            price: _price
        });
        emit AskNew(address(msg.sender), _nft, _tokenId, _quoteToken, _price);
    }

    /**
     * @notice Create ask order
     * @param _nft: contract address of the NFT
     * @param _tokenId: tokenId of the NFT
     * @param _quoteToken: quote token
     * @param _price: price for listing (in wei)
     */
    function cancelAsk(
        address _nft,
        uint256 _tokenId
    ) external nonReentrant {
        // Verify the sender has listed it
        require(asks[_nft][_tokenId].seller == msg.sender, "Ask: Token not listed");
        IERC721(_nft).safeTransferFrom(address(this), address(msg.sender), _tokenId);
        emit AskCancel(msg.sender, _nft, _tokenId);
    }

    /**
     * @notice Create ask order
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
    ) external nonReentrant {
        Ask memory ask = asks[_nft][_tokenId];

        require(ask.quoteToken == _quoteToken, "Buy: Incorrect qoute token");
        require(ask.price == _price, "Buy: Incorrect price");
        IERC20(_quoteToken).safeTransferFrom(address(msg.sender), address(this), netPrice);

        uint256 fees = distributeFees(_nft, _tokenId, _quoteToken, _price);
        uint256 netPrice = _price.sub(fees);
        IERC20(_quoteToken).safeTransfer(ask.seller, netPrice);
        IERC721(_nft).safeTransfer(address(msg.sender), _tokenId);
        delete asks[_nft][_tokenId];
        emit Trade(ask.seller, msg.sender, _nft, _tokenId, _quoteToken, _price, _netPrice);
    }


    /**
     * @notice Create ask order
     * @param _nft: contract address of the NFT
     * @param _tokenId: tokenId of the NFT
     * @param _quoteToken: quote token
     * @param _price: price for listing (in wei)
     */
    function buyUsingEth(
        address _nft,
        uint256 _tokenId
    ) external payable nonReentrant {
        IWETH(WETH).deposit{value: msg.value}();
        IWETH(WETH).safeTransfer(address(msg.sender), msg.value);
        buy(_nft, _tokenId, WETH, msg.value);
    }

    /**
     * @notice Create a offer
     * @param _nft: contract address of the NFT
     * @param _tokenId: tokenId of the NFT
     * @param _buyer
     * @param _quoteToken: quote token
     * @param _price: price for listing (in wei)
     */
    function acceptBid(
        address _nft,
        uint256 _tokenId,
        address _bidder,
        address _quoteToken,
        uint256 _price
    ) {
        require(asks[_nft][_tokenId].seller == msg.sender, "AcceptBid: only seller");
        Bid memory bid = bids[_nft][_tokenId][_bidder];
        require(bid.price == _price, "AcceptBid: invalid price");
        require(bid.quoteToken == _quoteToken, "AcceptBid: invalid quoteToken");
        uint256 fees = distributeFees(_nft, _tokenId, _quoteToken, _price);
        uint256 netPrice = _price.sub(fees);
        IERC20(_quoteToken).safeTransfer(ask.seller, netPrice);
        IERC721(_nft).safeTransfer(address(msg.sender), _tokenId);
        delete asks[_nft][_tokenId];
        delete bids[_nft][_tokenId][_bidder];
        emit Trade(ask.seller, msg.sender, _nft, _tokenId, _quoteToken, _price, _netPrice);
    }


    function _bid(
        address _nft,
        uint256 _tokenId,
        address _quoteToken,
        uint256 _price
    ) private {
        if (bids[_nft][_tokenId][msg.sender].price >0) {
            _cancelBid(_nft, _tokenId);
        }
        IERC20(_quoteToken).safeTransferFrom(address(msg.sender), address(this), _price);
        bids[_nft][_tokenId][msg.sender] = Bid({price: _price, quoteToken: _quoteToken});
        emit Bid(msg.sender, _nft, _tokenId, _quoteTokenId, _price);
    }

    function bidUsingEth(
        address _nft,
        uint256 _tokenId
    )  external payable nonReentrant {
        IWETH(WETH).deposit{value: msg.value}();
        IWETH(WETH).safeTransfer(address(msg.sender), msg.value);
        _bid(_nft, _tokenId, WETH, _price);
    }


    function cancelBid(
        address _nft,
        uint256 _tokenId
    ) external nonReentrant {
        _cancelBid(_nft, _tokenId);
    }

    function _cancelBid(
        address _nft,
        uint256 _tokenId
    ) private {
        Bid memory bid = bids[_nft][_tokenId][msg.sender];
        require(bid.price > 0, "Bid: bid not found");
        IERC20(bid.quoteToken).safeTransfer(address(msg.sender), bid.price);
        delete bids[_nft][_tokenId][msg.sender];
        emit CancelBid(msg.sender, _nft, _tokenId);
    }
}
