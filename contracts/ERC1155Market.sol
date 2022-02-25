// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma abicoder v2;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/ERC1155/IERC1155.sol";

contract ERC1155Market is ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using Counters for Counters.Counter;
    
    struct Ask {
        address seller;
        address nft,
        uint256 tokenId,
        uint256 quantity,
        uint256 quoteToken,
        uint256 pricePerUnit
    }

    struct Offer {
        address buyer;
        address nft,
        uint256 tokenId,
        uint256 quantity,
        uint256 quoteToken,
        uint256 pricePerUnit
    }

    Counters.Counter private _aksIds;
    Counters.Counter private _offerIds;

    mapping(uint256 => Ask) public asks;
    mapping(uint256 => Offer) public offers;

    event AskNew(
        uint256 askId,
        address seller;
        address nft,
        uint256 tokenId,
        uint256 quantity,
        uint256 quoteToken,
        uint256 pricePerUnit
    )

    event AskCancel(
        uint256 askId,
    )

    event OfferNew(
        uint256 offerId,
        address buyer;
        address nft,
        uint256 tokenId,
        uint256 quantity,
        uint256 quoteToken,
        uint256 pricePerUnit
    )

    event CancelOffer(
        uint256 offerId,
    )

    event OfferAccept(
        uint256 offerId,
        address seller,
        uint256 quantity,
        uint256 price,
        uint256 netPrice,
    )

    event Buy(
        uint256 askId,
        address buyer,
        uint256 quantity,
        uint256 price,
        uint256 netPrice,
    )

    /**
     * @notice Create ask order
     * @param _nft: contract address of the NFT
     * @param _tokenId: tokenId of the NFT
     * @param _quantity: quantity of order
     * @param _quoteToken: quote token
     * @param _pricePerUnit: price per unit (in wei)
     */
    function createAsk(
        address _nft,
        uint256 _tokenId,
        uint256 _quantity,
        address _quoteToken,
        uint256 _pricePerUnit
    ) external nonReentrant {
        _askIds.increment();
        IERC1155(_nft).safeTransferFrom(_msgSender(), _tokenId, _quantity);
        asks[_askIds.current()] = Ask({
            seller: _msgSender(),
            nft: _nft,
            tokenId: _tokenId,
            quoteToken: _quoteToken,
            pricePerUnit: _pricePerUnit,
            quantity: _quantity
        })

        emit AskNew(
            _askIds.current(),
            _msgSender(),
            nft,
            tokenId,
            quoteToken,
            pricePerUnit,
            quantity
        )
    }

    /**
     * @notice Cancel Ask
     * @param _askId: askId
     */
    function cancelAsk(uint256 askId) external nonReentrant {
        require(asks[askId].seller == _msgSender(), "ERC1155Market: only seller");
        Ask memory ask = asks[askId];
        IERC1155(ask.nft).safeTransferFrom(address(this), ask.seller, ask.tokenId, ask.quantity);
        delete asks[askId];
    }

    /**
     * @notice Offer
     * @param _askId: askId
     */
    function offer(
        address _nft,
        uint256 _tokenId,
        uint256 _quantity,
        address _quoteToken,
        uint256 _pricePerUnit
    ) external nonReentrant {
        _offerIds.increment();
        IERC20(_quoteToken).safeTransferFrom(_msgSender(), address(this), _pricePerUnit.mul(_quantity));
        offers[_offerIds.current()] = Ask({
            buyer: _msgSender(),
            nft: _nft,
            tokenId: _tokenId,
            quoteToken: _quoteToken,
            pricePerUnit: _pricePerUnit,
            quantity: _quantity
        })
        emit OfferNew(
            _offerIds.current(),
            _msgSender(),
            _nft,
            _tokenId,
            _quantity,
            _quoteToken,
            _pricePerUnit
        )
    }

    /**
     * @notice Cancel Offer
     * @param offerId: id of the offer
     */
    function cancelOffer(uint256 offerId) external nonReentrant {
        require(offers[offerId].seller == _msgSender(), "ERC1155Market: only offer owner");
        Offer memory offer = offers[offerId];
        IERC20(offer.quoteToken).safeTransfer(offer.buyer, offer.pricePerUnit.mul(offer.quantity));
        delete offers[offerId];
    }

    /**
     * @notice Accept Offer
     * @param offerId: id of the offer
     */
    function acceptOffer(uint256 offerId, uint256 quantity)
        external
        nonReentrant
    {
        Offer storage offer = offers[offerId];
        offer.quantity = offer.quantity.sub(quantity);
        IERC1155(offer.nft).safeTransferFrom(_msgSender(), offer.buyer, offer.tokenId, quantity);
        IERC20(offer.quoteToken).safeTransfer(_msgSender(), offer.pricePerUnit.mul(quantity));
        if (offer.quantity == 0) {
            delete offers[offerId]
        }
        emit OfferAccept(offerId, _msgSender(), quantity);
    }

    function buy(uint256 askId, uint256 quantity) external nonReentrant {
        Ask storage ask = asks[askId];
        ask.quantity = ask.quantity.sub(quantity);
        uint256 price = ask.pricePerUnit.mul(quantity);
        IERC20(ask.quoteToken).safeTransferFrom(_msgSender(), ask.seller, price);
        IERC1155(ask.nft).safeTransfer(_msgSender(), ask.tokenId, quantity);
        if (ask.quantity == 0) {
            delete ask[offerId]
        }

        emit Buy(
            askId,
            _msgSender(),
            quantity,
            price,
            price
        )
    }
}
