// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma abicoder v2;
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

contract ERC721NFTRent is ERC721Holder {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct Lending {
        address lender; // address of nft
        address renter; // address of renter
        uint256 expiredAt; // expired at
        address quoteToken; // quote token
        uint256 pricePerDay; // price per day
    }

    mapping(address => mapping(uint256 => Lending)) public lendings;

    event Lend(
        address nft,
        uint256 tokenId,
        address lender,
        address quoteToken,
        uint256 pricePerDay
    );

    event CancelLend(
        address nft,
        uint256 tokenId
    );

    event Rent(
        address nft,
        uint256 tokenId,
        address renter,
        uint256 expiredAt
    );

    /**
     * @notice Lend NFT
     * @param _nft: contract address of the NFT
     * @param _tokenId: tokenId of the NFT
     * @param _quoteToken: quote token address
     * @param _pricePerDay: Price per day
     */
    function lend(address _nft, uint256 _tokenId, address _quoteToken, uint256 _pricePerDay) external {
        IERC721(_nft).safeTransferFrom(address(msg.sender), address(this), _tokenId);
        lendings[_nft][_tokenId] = Lending({
            lender: address(msg.sender),
            renter: address(0x0),
            expiredAt: 0,
            quoteToken: _quoteToken,
            pricePerDay: _pricePerDay
        });
        emit Lend(_nft, _tokenId, address(msg.sender), _quoteToken, _pricePerDay);
    }

    function cancelLend(address _nft, uint256 _tokenId) external{
        require(lendings[_nft][_tokenId].lender == msg.sender, "ERC721NFTRent:only lender");
        require(lendings[_nft][_tokenId].expiredAt <= block.timestamp, "ERC721NFTRent: not expired");
        delete lendings[_nft][_tokenId];
        IERC721(_nft).safeTransferFrom(address(this), address(msg.sender), _tokenId);
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
    function rent(address _nft, uint256 _tokenId, uint256 _duration , address _quoteToken, uint256 _pricePerDay) external {
        require(lendings[_nft][_tokenId].lender != address(0x0), "ERC721NFTRent: not listed");
        require(lendings[_nft][_tokenId].expiredAt <= block.timestamp, "ERC721NFTRent: has renter");
        require(lendings[_nft][_tokenId].pricePerDay == _pricePerDay, "ERC721NFTRent: invalid pricePerDay");
        require(lendings[_nft][_tokenId].quoteToken == _quoteToken, "ERC721NFTRent: invalid quoteToken");
        require(_duration >=86400, "ERC721NFTRent: duration must be greater than 1 day");
        uint256 rentDay = _duration.div(86400);
        uint256 expiredAt = block.timestamp.add(rentDay * 86400);
        uint256 price = _pricePerDay.mul(rentDay);
        IERC20(_quoteToken).safeTransferFrom(address(msg.sender), lendings[_nft][_tokenId].lender, price);
        lendings[_nft][_tokenId].expiredAt = expiredAt;
        lendings[_nft][_tokenId].renter = address(msg.sender);
        emit Rent(_nft, _tokenId, address(msg.sender), expiredAt);
    }
}