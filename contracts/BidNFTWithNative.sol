// SPDX-License-Identifier: MIT

pragma solidity =0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./libraries/TransferHelper.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


contract BidNFTWithNative is ERC721Holder, Ownable, Pausable, ReentrancyGuard {
    using SafeMath for uint256;
    using Address for address;
    using EnumerableSet for EnumerableSet.AddressSet;

    struct BidEntry {
        address bidder;
        uint256 price;
    }

    IERC721 public nft;
    address public feeAddr;
    uint256 public feePercent = 250;
    uint256 public royaltyFeePercent = 250;
    address public royaltyFeeRecipient;
    uint256 private _MAX_FEE = 1000;

    mapping(uint256 => uint256) public prices;
    mapping(uint256 => address) public sellers;
    mapping(uint256 => mapping(address => uint256)) userBidPrice;
    mapping(uint256 => EnumerableSet.AddressSet) private tokenBids;

    event Trade(
        address indexed seller,
        address indexed buyer,
        uint256 indexed tokenId,
        uint256 price,
        uint256 fee
    );
    event BidAccept(
        address indexed seller,
        address indexed buyer,
        uint256 indexed tokenId,
        uint256 price,
        uint256 fee
    );
    event Ask(address indexed seller, uint256 indexed tokenId, uint256 price);
    event CancelSellToken(address indexed seller, uint256 indexed tokenId);
    event UpdatedFeeAddress(
        address indexed previousFeeAddr,
        address indexed newFeeAddr
    );
    event SetFeePercent(
        address indexed seller,
        uint256 oldFeePercent,
        uint256 newFeePercent
    );
    event Bid(address indexed bidder, uint256 indexed tokenId, uint256 price);
    event CancelBidToken(address indexed bidder, uint256 indexed tokenId);

    modifier onlySeller(uint256 _tokenId) {
        require(sellers[_tokenId] == _msgSender(), "caller is not the seller");
        _;
    }

    constructor(
        address _nftAddress,
        address _feeAddr,
        uint256 _feePercent,
        address _royaltyFeeRecipient,
        uint256 _royaltyFeePercent
    ) public {
        require(_nftAddress != address(0) && _nftAddress != address(this));
        nft = IERC721(_nftAddress);
        feeAddr = _feeAddr;
        feePercent = _feePercent;
        royaltyFeePercent = _royaltyFeePercent;
        royaltyFeeRecipient = _royaltyFeeRecipient;
        emit UpdatedFeeAddress(address(0), feeAddr);
        emit SetFeePercent(_msgSender(), 0, feePercent);
    }

    function buyToken(uint256 _tokenId) public payable whenNotPaused{
        buyTokenTo(_tokenId, _msgSender());
    }

    function buyTokenTo(uint256 _tokenId, address _to)
        public
        payable
        whenNotPaused
        nonReentrant
    {
        uint256 price = prices[_tokenId];
        require(price > 0, "Token not in sell book");
        require(msg.value >= price, "invalid value");

        nft.safeTransferFrom(address(this), _to, _tokenId);
        uint256 sumFees = _distributeFees(price);
        uint256 netPrice = price.sub(sumFees);
        TransferHelper.safeTransferETH(sellers[_tokenId], netPrice);
        address seller = sellers[_tokenId];

        delete prices[_tokenId];
        delete sellers[_tokenId];

        if (msg.value > price) {
            TransferHelper.safeTransferETH(_msgSender(), msg.value.sub(price));
        }

        emit Trade(seller, _msgSender(), _tokenId, price, sumFees);
    }

    function setCurrentPrice(uint256 _tokenId, uint256 _price)
        public
        whenNotPaused
        onlySeller(_tokenId)
        nonReentrant
    {
        require(_price != 0, "Price must be granter than zero");
        prices[_tokenId] = _price;
        emit Ask(_msgSender(), _tokenId, _price);
    }
    
    function batchSetCurrentPrice(uint256[] calldata _tokenIds, uint256[] calldata _prices) public{
        require(_tokenIds.length == _prices.length);
        for (uint i = 0; i < _tokenIds.length; i++) {
            setCurrentPrice(_tokenIds[i], _prices[i]);
        }
    }

    function readyToSellToken(uint256 _tokenId, uint256 _price)
        public
        whenNotPaused
    {
        readyToSellTokenTo(_tokenId, _price, address(_msgSender()));
    }
    
    function batchReadyToSellToken(uint256[] calldata _tokenIds, uint256[] calldata _prices) public{
        require(_tokenIds.length == _prices.length);
        for (uint i = 0; i < _tokenIds.length; i++) {
            readyToSellToken(_tokenIds[i], _prices[i]);
        }
    }

    function readyToSellTokenTo(
        uint256 _tokenId,
        uint256 _price,
        address _to
    ) public whenNotPaused nonReentrant{
        require(!_isContract(_msgSender()), "Contract call not allow");
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

    function cancelSellToken(uint256 _tokenId)
        public
        whenNotPaused
        onlySeller(_tokenId)
        nonReentrant
    {
        nft.safeTransferFrom(address(this), _msgSender(), _tokenId);
        delete prices[_tokenId];
        delete sellers[_tokenId];
        emit CancelSellToken(_msgSender(), _tokenId);
    }
    
    function batchCancelSellToken(uint256[] calldata _tokenIds) public{
        for (uint i = 0; i < _tokenIds.length; i ++) {
            cancelSellToken(_tokenIds[i]);
        }
    }

    function bidToken(uint256 _tokenId) public payable whenNotPaused nonReentrant{
        require(userBidPrice[_tokenId][_msgSender()] == 0, "Bidder found");
        require(msg.value != 0, "Price must be granter than zero");
        userBidPrice[_tokenId][_msgSender()] = msg.value;
        tokenBids[_tokenId].add(_msgSender());
        emit Bid(_msgSender(), _tokenId, msg.value);
    }

    function _distributeFees(uint256 price) private returns (uint256) {
        uint256 sumFees = 0;

        if (feeAddr != address(0)) {
            uint256 feeAmount = price.mul(feePercent).div(10000);
            if (feeAmount != 0) {
                sumFees = feeAmount;
                TransferHelper.safeTransferETH(feeAddr, feeAmount);
            }
            
        }

        if (royaltyFeeRecipient != address(0)) {
            uint256 royaltyFee = price.mul(royaltyFeePercent).div(10000);
            if (royaltyFee != 0) {
                sumFees = sumFees.add(royaltyFee);
                TransferHelper.safeTransferETH(royaltyFeeRecipient, royaltyFee);
            }
        }

        return sumFees;
    }

    function sellTokenTo(
        uint256 _tokenId,
        address _to,
        uint256 _price
    ) public whenNotPaused onlySeller(_tokenId) nonReentrant{
        uint256 price = getUserBidPriceAndRemove(_tokenId, _to);
        require(price == _price, "invalid price");
        nft.safeTransferFrom(address(this), _to, _tokenId);

        uint256 sumFees = _distributeFees(price);
        uint256 netPrice = price.sub(sumFees);
        TransferHelper.safeTransferETH(sellers[_tokenId], netPrice);
        address seller = sellers[_tokenId];
        delete prices[_tokenId];
        delete sellers[_tokenId];

        emit BidAccept(seller, _to, _tokenId, price, sumFees);
    }

    function getUserBidPriceAndRemove(uint256 _tokenId, address bidder)
        private
        returns (uint256)
    {
        require(tokenBids[_tokenId].contains(bidder), "bidder not found");
        uint256 price = userBidPrice[_tokenId][bidder];
        tokenBids[_tokenId].remove(bidder);
        delete userBidPrice[_tokenId][bidder];
        return price;
    }

    function cancelBidToken(uint256 _tokenId) public whenNotPaused nonReentrant{
        require(userBidPrice[_tokenId][_msgSender()] > 0, "Bidder not found");
        uint256 price = userBidPrice[_tokenId][_msgSender()];
        userBidPrice[_tokenId][_msgSender()] = 0;
        tokenBids[_tokenId].remove(_msgSender());
        TransferHelper.safeTransferETH(_msgSender(), price);
        emit CancelBidToken(_msgSender(), _tokenId);
    }

    function getBids(uint256 _tokenId) public view returns (BidEntry[] memory) {
        BidEntry[] memory bids = new BidEntry[](tokenBids[_tokenId].length());
        for (uint256 i = 0; i < tokenBids[_tokenId].length(); i++) {
            address bidder = tokenBids[_tokenId].at(i);
            bids[i] = BidEntry({
                bidder: bidder,
                price: userBidPrice[_tokenId][bidder]
            });
        }
        return bids;
    }

    function setFeeAddress(address _feeAddr) public onlyOwner {
        emit UpdatedFeeAddress(feeAddr, _feeAddr);
        feeAddr = _feeAddr;
    }

    function setFeePercent(uint256 _feePercent) public onlyOwner {
        require(_feePercent <= _MAX_FEE, "MAX FEE");
        emit SetFeePercent(_msgSender(), feePercent, _feePercent);
        feePercent = _feePercent;
    }

    function setRoyaltyAddress(address _feeAddr) public onlyOwner {
        royaltyFeeRecipient = _feeAddr;
    }

    function setRoyaltyFeePercent(uint256 _feePercent) public onlyOwner {
        require(_feePercent <= _MAX_FEE, "MAX FEE");
        royaltyFeePercent = _feePercent;
    }

    function pause() public onlyOwner whenNotPaused {
        _pause();
    }

    function unpause() public onlyOwner whenPaused {
        _unpause();
    }

    /**
     * @notice Check if an address is a contract
     */
    function _isContract(address _addr) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(_addr)
        }
        return size > 0;
    }
}
