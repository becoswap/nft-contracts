// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma abicoder v2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract ERC721NFTFeeDistributor is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public protocolFeeRecipient;
    uint256 public protocolFeePercent = 250;
    mapping(address => uint256) loyaltyFeePercent;

    uint256 public MAX_FEE = 500; // 5%

    struct Collection {
        uint256 loyaltyFeePercent;
        address loyaltyFeeRecipient;
    }

    mapping(address => Collection) public collections;
    event CollectionUpdated(address owner, Collection collection);

    constructor(address _recipient, uint256 _feePercent) {
        protocolFeeRecipient = _recipient;
        protocolFeePercent = _feePercent;
    }

    function setCollection(
        address _nft,
        address _recipient,
        uint256 _percent
    ) external onlyOwner {
        require(_percent <= MAX_FEE, "max_fee");
        require(_nft != address(0), "zero address");
        require(_recipient != address(0), "zero address");
        collections[_nft] = Collection({
            loyaltyFeePercent: _percent,
            loyaltyFeeRecipient: _recipient
        });
        emit CollectionUpdated(_msgSender(), collections[_nft]);
    }

    function setProtocolFeeRecipient(address _recipient) external onlyOwner {
        require(
            _recipient != address(0),
            "Erc721NFTFeeDistributor: zero address"
        );
        protocolFeeRecipient = _recipient;
    }

    function setProtocolFeePercent(uint256 _percent) external onlyOwner {
        require(_percent <= MAX_FEE, "max_fee");
        protocolFeePercent = _percent;
    }

    function _distributeFees(
        address _nft,
        address _quoteToken,
        uint256 _price
    ) internal virtual returns (uint256) {
        uint256 fee = 0;
        uint256 sumFees = 0;

        if (protocolFeeRecipient != address(0)) {
            fee = _price.mul(protocolFeePercent).div(10000);
            IERC20(_quoteToken).safeTransfer(protocolFeeRecipient, fee);
            sumFees = sumFees.add(fee);
        }

        Collection memory cfg = collections[_nft];

        if (cfg.loyaltyFeeRecipient != address(0)) {
            fee = _price.mul(cfg.loyaltyFeePercent).div(10000);
            if (fee > 0) {
                IERC20(_quoteToken).safeTransfer(cfg.loyaltyFeeRecipient, fee);
            }
            sumFees = sumFees.add(fee);
        }
        return sumFees;
    }
}
