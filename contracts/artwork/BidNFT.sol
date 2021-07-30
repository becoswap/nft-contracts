// SPDX-License-Identifier: MIT

pragma solidity =0.8.0;
pragma experimental ABIEncoderV2;

import "../interfaces/IBidNFT.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "../interfaces/IArtworkNFT.sol";

contract BidNFT is IBidNFT, ERC721Holder, Ownable, Pausable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using Address for address;

    uint256 MAX_BID = 100;

    struct BidEntry {
        address bidder;
        uint256 price;
    }

    IArtworkNFT public nft;
    IERC20 public quoteErc20;
    address public feeAddr;
    uint256 public feePercent;
    mapping(uint256 => uint256) public prices;
    mapping(uint256 => address) public sellers;
    mapping(uint256 => mapping(address => uint256)) userBidPrice;
    mapping(uint256 => BidEntry[]) public tokenBids;

    event Trade(
        address indexed seller,
        address indexed buyer,
        uint256 indexed tokenId,
        uint256 price,
        uint256 fee
    );
    event Ask(address indexed seller, uint256 indexed tokenId, uint256 price);
    event CancelSellToken(address indexed seller, uint256 indexed tokenId);
    event FeeAddressTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );
    event SetFeePercent(
        address indexed seller,
        uint256 oldFeePercent,
        uint256 newFeePercent
    );
    event Bid(address indexed bidder, uint256 indexed tokenId, uint256 price);
    event CancelBidToken(address indexed bidder, uint256 indexed tokenId);

    constructor(
        address _nftAddress,
        address _quoteErc20Address,
        address _feeAddr,
        uint256 _feePercent
    ) public {
        require(_nftAddress != address(0) && _nftAddress != address(this));
        require(
            _quoteErc20Address != address(0) &&
                _quoteErc20Address != address(this)
        );
        nft = IArtworkNFT(_nftAddress);
        quoteErc20 = IERC20(_quoteErc20Address);
        feeAddr = _feeAddr;
        feePercent = _feePercent;
        emit FeeAddressTransferred(address(0), feeAddr);
        emit SetFeePercent(_msgSender(), 0, feePercent);
    }

    function buyToken(uint256 _tokenId) public override whenNotPaused {
        buyTokenTo(_tokenId, _msgSender());
    }

    function buyTokenTo(uint256 _tokenId, address _to)
        public
        override
        whenNotPaused
    {
        uint256 price = prices[_tokenId];
        require(price > 0, "Token not in sell book");

        nft.safeTransferFrom(address(this), _to, _tokenId);
        uint256 feeAmount = price.mul(feePercent).div(100);
        if (feeAmount != 0) {
            quoteErc20.safeTransferFrom(_msgSender(), feeAddr, feeAmount);
        }

        address creator;
        uint256 royalties;
        (creator, royalties) = nft.profiles(_tokenId);
        uint256 royaltyAmount = price.mul(royalties).div(100);
        if (royaltyAmount > 0) {
            quoteErc20.safeTransferFrom(_msgSender(), creator, royaltyAmount);
        }
        quoteErc20.safeTransferFrom(
            _msgSender(),
            sellers[_tokenId],
            price.sub(royaltyAmount).sub(feeAmount)
        );
        address seller = sellers[_tokenId];

        delete prices[_tokenId];
        delete sellers[_tokenId];

        emit Trade(
            seller,
            msg.sender,
            _tokenId,
            price,
            royaltyAmount.add(feeAmount)
        );
    }

    function setCurrentPrice(uint256 _tokenId, uint256 _price)
        public
        override
        whenNotPaused
    {
        require(
            sellers[_tokenId] == _msgSender(),
            "Only Seller can update price"
        );
        prices[_tokenId] = _price;
        emit Ask(_msgSender(), _tokenId, _price);
    }

    function readyToSellToken(uint256 _tokenId, uint256 _price)
        public
        override
        whenNotPaused
    {
        readyToSellTokenTo(_tokenId, _price, address(_msgSender()));
    }

    function readyToSellTokenTo(
        uint256 _tokenId,
        uint256 _price,
        address _to
    ) public override whenNotPaused {
        require(
            _msgSender() == nft.ownerOf(_tokenId),
            "Only Token Owner can sell token"
        );
        require(_price != 0, "Price must be granter than zero");
        nft.safeTransferFrom(address(_msgSender()), address(this), _tokenId);

        prices[_tokenId] = _price;
        sellers[_tokenId] = _to;

        emit Ask(_to, _tokenId, _price);
    }

    function cancelSellToken(uint256 _tokenId) public override whenNotPaused {
        require(
            sellers[_tokenId] == _msgSender(),
            "Only Seller can cancel sell token"
        );
        nft.safeTransferFrom(address(this), _msgSender(), _tokenId);

        delete prices[_tokenId];
        delete sellers[_tokenId];

        emit CancelSellToken(_msgSender(), _tokenId);
    }

    function bidToken(uint256 _tokenId, uint256 _price)
        public
        override
        whenNotPaused
    {
        require(_price != 0, "Price must be granter than zero");

        if (userBidPrice[_tokenId][msg.sender] > 0) {
            updateBidPrice(_tokenId, _price);
        } else {
            require(tokenBids[_tokenId].length < MAX_BID, "max bid");
            quoteErc20.safeTransferFrom(_msgSender(), address(this), _price);
            userBidPrice[_tokenId][msg.sender] = _price;
            tokenBids[_tokenId].push(
                BidEntry({bidder: msg.sender, price: _price})
            );
        }
        emit Bid(msg.sender, _tokenId, _price);
    }

    function updateBidPrice(uint256 _tokenId, uint256 _price) private {
        uint256 bidLength = tokenBids[_tokenId].length;
        for (uint256 i = 0; i < bidLength; i++) {
            if (tokenBids[_tokenId][i].bidder == msg.sender) {
                uint256 currentPrice = tokenBids[_tokenId][i].price;
                if (_price > currentPrice) {
                    quoteErc20.safeTransferFrom(
                        address(_msgSender()),
                        address(this),
                        _price - currentPrice
                    );
                } else {
                    quoteErc20.safeTransfer(msg.sender, currentPrice - _price);
                }
                tokenBids[_tokenId][i].price = _price;
                userBidPrice[_tokenId][msg.sender] = _price;
                return;
            }
        }
    }

    function sellTokenTo(uint256 _tokenId, address _to) public override {
        require(
					sellers[_tokenId] == _msgSender(),
					"Only Seller can sell token"
        );
        uint256 price = getUserBidPriceAndRemove(_tokenId, _to);
        require(price > 0, "bidder not found");
        nft.safeTransferFrom(address(this), _to, _tokenId);

        uint256 feeAmount = price.mul(feePercent).div(100);
        if (feeAmount != 0) {
            quoteErc20.safeTransfer(feeAddr, feeAmount);
        }
        address creator;
        uint256 royalties;
        (creator, royalties) = nft.profiles(_tokenId);
        uint256 royaltyAmount = price.mul(royalties).div(100);
        if (royaltyAmount > 0) {
            quoteErc20.safeTransfer(creator, royaltyAmount);
            price = price.sub(royaltyAmount);
        }
        quoteErc20.safeTransfer(sellers[_tokenId], price.sub(feeAmount));
        address seller = sellers[_tokenId];
        delete prices[_tokenId];
        delete sellers[_tokenId];

        emit Trade(seller, _to, _tokenId, price, royaltyAmount.add(feeAmount));
    }

    function getUserBidPriceAndRemove(uint256 _tokenId, address bidder)
        private
        returns (uint256)
    {
        uint256 bidLength = tokenBids[_tokenId].length;
        for (uint256 i = 0; i < bidLength; i++) {
            if (tokenBids[_tokenId][i].bidder == bidder) {
                uint256 price = tokenBids[_tokenId][i].price;
                tokenBids[_tokenId][i] = tokenBids[_tokenId][bidLength - 1];
                tokenBids[_tokenId].pop();
                return price;
            }
        }
        return 0;
    }

    function cancelBidToken(uint256 _tokenId) public override whenNotPaused {
        require(userBidPrice[_tokenId][msg.sender] > 0, "Bidder not found");
        uint256 bidLength = tokenBids[_tokenId].length;
        for (uint256 i = 0; i < bidLength; i++) {
            if (tokenBids[_tokenId][i].bidder == msg.sender) {
                quoteErc20.safeTransfer(
                    msg.sender,
                    tokenBids[_tokenId][i].price
                );
                tokenBids[_tokenId][i] = tokenBids[_tokenId][bidLength - 1];
                tokenBids[_tokenId].pop();
                userBidPrice[_tokenId][msg.sender] = 0;
                emit CancelBidToken(msg.sender, _tokenId);
                return;
            }
        }
    }

    function getBids(uint256 _tokenId) public view returns (BidEntry[] memory) {
        return tokenBids[_tokenId];
    }

    function transferFeeAddress(address _feeAddr) public {
        require(_msgSender() == feeAddr, "FORBIDDEN");
        feeAddr = _feeAddr;
        emit FeeAddressTransferred(_msgSender(), feeAddr);
    }

    function setFeePercent(uint256 _feePercent) public onlyOwner {
        require(feePercent != _feePercent, "Not need update");
        emit SetFeePercent(_msgSender(), feePercent, _feePercent);
        feePercent = _feePercent;
    }

    function pause() public onlyOwner whenNotPaused {
        _pause();
    }

    function unpause() public onlyOwner whenPaused {
        _unpause();
    }
}
