// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma abicoder v2;
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Erc721NFTFeeDistributor.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract ERC721NFTRent is
    ERC721Holder,
    Ownable,
    Erc721NFTFeeDistributor,
    ReentrancyGuard
{
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct Lending {
        address lender; // address of nft
        address renter; // address of renter
        uint256 expiredAt; // expired at
        address quoteToken; // quote token
        uint256 pricePerDay; // price per day
    }

    struct Offer {
        uint256 duration; // duration
        address quoteToken; // quote token
        uint256 pricePerDay; // price per day
    }

    mapping(address => mapping(uint256 => Lending)) public lendings;
    mapping(address => mapping(uint256 => mapping(address => Offer)))
        public offers;

    event Lend(
        address nft,
        uint256 tokenId,
        address lender,
        address quoteToken,
        uint256 pricePerDay
    );

    event CancelLend(address nft, uint256 tokenId);

    event Rent(
        address nft,
        uint256 tokenId,
        address renter,
        uint256 expiredAt,
        uint256 price,
        uint256 netPrice
    );

    event OfferNew(
        address nft,
        uint256 tokenId,
        address renter,
        uint256 duration,
        address quoteToken,
        uint256 pricePerDay
    );

    event OfferCancel(address nft, uint256 tokenId, address renter);

    event OfferAccept(
        address nft,
        uint256 tokenId,
        address renter,
        uint256 expiredAt,
        uint256 price,
        uint256 netPrice
    );

    modifier notContract() {
        require(!_isContract(msg.sender), "Contract not allowed");
        require(msg.sender == tx.origin, "Proxy contract not allowed");
        _;
    }

    constructor(
        address _feeProvider,
        address _feeRecipient,
        uint256 _feePercent
    ) Erc721NFTFeeDistributor(_feeProvider, _feeRecipient, _feePercent) {}

    /**
     * @notice Lend NFT
     * @param _nft: contract address of the NFT
     * @param _tokenId: tokenId of the NFT
     * @param _quoteToken: quote token address
     * @param _pricePerDay: Price per day
     */
    function lend(
        address _nft,
        uint256 _tokenId,
        address _quoteToken,
        uint256 _pricePerDay
    ) external nonReentrant notContract {
        IERC721(_nft).safeTransferFrom(
            address(msg.sender),
            address(this),
            _tokenId
        );
        lendings[_nft][_tokenId] = Lending({
            lender: address(msg.sender),
            renter: address(0x0),
            expiredAt: 0,
            quoteToken: _quoteToken,
            pricePerDay: _pricePerDay
        });
        emit Lend(
            _nft,
            _tokenId,
            address(msg.sender),
            _quoteToken,
            _pricePerDay
        );
    }

    function cancelLend(address _nft, uint256 _tokenId) external nonReentrant {
        require(
            lendings[_nft][_tokenId].lender == msg.sender,
            "ERC721NFTRent:only lender"
        );
        require(
            lendings[_nft][_tokenId].expiredAt <= block.timestamp,
            "ERC721NFTRent: not expired"
        );
        delete lendings[_nft][_tokenId];
        IERC721(_nft).safeTransferFrom(
            address(this),
            address(msg.sender),
            _tokenId
        );
        emit CancelLend(_nft, _tokenId);
    }

    /**
     * @notice Rent NFT
     * @param _nft: contract address of the NFT
     * @param _tokenId: tokenId of the NFT
     * @param _duration: duration
     * @param _quoteToken: quote token address
     * @param _pricePerDay: Price per day
     */
    function rent(
        address _nft,
        uint256 _tokenId,
        uint256 _duration,
        address _quoteToken,
        uint256 _pricePerDay
    ) external nonReentrant notContract {
        require(
            lendings[_nft][_tokenId].lender != address(0x0),
            "ERC721NFTRent: not listed"
        );
        require(
            lendings[_nft][_tokenId].expiredAt <= block.timestamp,
            "ERC721NFTRent: has renter"
        );
        require(
            lendings[_nft][_tokenId].pricePerDay == _pricePerDay,
            "ERC721NFTRent: invalid pricePerDay"
        );
        require(
            lendings[_nft][_tokenId].quoteToken == _quoteToken,
            "ERC721NFTRent: invalid quoteToken"
        );
        require(
            _duration >= 86400,
            "ERC721NFTRent: duration must be greater than 1 day"
        );
        uint256 rentDay = _duration.div(86400);
        uint256 expiredAt = block.timestamp.add(rentDay * 86400);
        uint256 price = _pricePerDay.mul(rentDay);

        IERC20(_quoteToken).safeTransferFrom(
            address(msg.sender),
            address(this),
            price
        );
        uint256 fees = _distributeFees(_nft, _tokenId, _quoteToken, price);
        uint256 netPrice = price.sub(fees);
        IERC20(_quoteToken).safeTransfer(
            lendings[_nft][_tokenId].lender,
            netPrice
        );
        lendings[_nft][_tokenId].expiredAt = expiredAt;
        lendings[_nft][_tokenId].renter = address(msg.sender);
        emit Rent(
            _nft,
            _tokenId,
            address(msg.sender),
            expiredAt,
            price,
            netPrice
        );
    }

    /**
     * @notice Offer NFT
     * @param _nft: contract address of the NFT
     * @param _tokenId: tokenId of the NFT
     * @param _duration: duration
     * @param _quoteToken: quote token address
     * @param _pricePerDay: Price per day
     */
    function offer(
        address _nft,
        uint256 _tokenId,
        uint256 _duration,
        address _quoteToken,
        uint256 _pricePerDay
    ) external nonReentrant notContract {
        require(
            _duration >= 86400,
            "ERC721NFTRent: duration must be greater than 1 day"
        );
        if (offers[_nft][_tokenId][address(msg.sender)].duration > 0) {
            _cancelOffer(_nft, _tokenId);
        }
        offers[_nft][_tokenId][address(msg.sender)] = Offer({
            duration: _duration,
            quoteToken: _quoteToken,
            pricePerDay: _pricePerDay
        });
        uint256 rentDay = _duration.div(86400);
        uint256 price = _pricePerDay.mul(rentDay);
        IERC20(_quoteToken).safeTransferFrom(
            address(msg.sender),
            address(this),
            price
        );
        emit OfferNew(
            _nft,
            _tokenId,
            address(msg.sender),
            _duration,
            _quoteToken,
            _pricePerDay
        );
    }

    /**
     * @notice Offer NFT
     * @param _nft: contract address of the NFT
     * @param _tokenId: tokenId of the NFT
     */
    function cancelOffer(address _nft, uint256 _tokenId) external nonReentrant {
        _cancelOffer(_nft, _tokenId);
    }

    function _cancelOffer(address _nft, uint256 _tokenId) private {
        require(
            offers[_nft][_tokenId][address(msg.sender)].duration > 0,
            "ERC721NFTRent: offer not found"
        );
        Offer memory offer = offers[_nft][_tokenId][address(msg.sender)];
        uint256 rentDay = offer.duration.div(86400);
        uint256 price = offer.pricePerDay.mul(rentDay);
        IERC20(offer.quoteToken).safeTransfer(address(msg.sender), price);
        delete offers[_nft][_tokenId][address(msg.sender)];
        emit OfferCancel(_nft, _tokenId, address(msg.sender));
    }

    /**
     * @notice Offer NFT
     * @param _nft: contract address of the NFT
     * @param _tokenId: tokenId of the NFT
     * @param _duration: duration
     * @param _quoteToken: quote token address
     * @param _pricePerDay: Price per day
     */
    function acceptOffer(
        address _nft,
        uint256 _tokenId,
        address renter,
        uint256 _duration,
        address _quoteToken,
        uint256 _pricePerDay
    ) external nonReentrant {
        require(
            offers[_nft][_tokenId][renter].duration > 0,
            "ERC721NFTRent: offer not found"
        );
        require(
            offers[_nft][_tokenId][renter].quoteToken == _quoteToken,
            "ERC721NFTRent: incorect quoteToken"
        );
        require(
            offers[_nft][_tokenId][renter].pricePerDay == _pricePerDay,
            "ERC721NFTRent: incorect pricePerDay"
        );
        require(
            lendings[_nft][_tokenId].expiredAt <= block.timestamp,
            "ERC721NFTRent: not expired"
        );
        address lender = lendings[_nft][_tokenId].lender;
        if (lender ==  address(msg.sender)) {
            IERC721(_nft).safeTransferFrom(
                address(msg.sender),
                address(this),
                _tokenId
            );

            lender = address(msg.sender);
        }
        Offer memory offer = offers[_nft][_tokenId][renter];
        uint256 rentDay = offer.duration.div(86400);
        uint256 price = offer.pricePerDay.mul(rentDay);
        uint256 fees = _distributeFees(_nft, _tokenId, _quoteToken, price);
        uint256 netPrice = price.sub(fees);
        uint256 expiredAt = block.timestamp.add(rentDay * 86400);
        IERC20(_quoteToken).safeTransfer(lender, netPrice);
        delete offers[_nft][_tokenId][renter];
        lendings[_nft][_tokenId] = Lending({
            lender: lender,
            renter: renter,
            expiredAt: expiredAt,
            quoteToken: _quoteToken,
            pricePerDay: _pricePerDay
        });
        emit OfferAccept(_nft, _tokenId, renter, expiredAt, price, netPrice);
    }

    function _isContract(address _addr) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(_addr)
        }
        return size > 0;
    }
}
