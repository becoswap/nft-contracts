// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma abicoder v2;

import "./interfaces/IFeeProvider.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Erc721NFTFeeDistributor is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public feeProvider;
    address public protocolFeeRecipient;
    uint256 public protocolFeePercent = 2500;

    constructor(address _feeProvider, address _recipient, uint256 _feePercent) {
        feeProvider = _feeProvider;
        protocolFeeRecipient = _recipient;
        protocolFeePercent = _feePercent;
    }

    function setFeeProvider(address _feeProvider) external onlyOwner {
        feeProvider = _feeProvider;
    }

    function setProtocolFeeRecipient(address _recipient) external onlyOwner {
        protocolFeeRecipient = _recipient;
    }

    function setProtocolFeePercent(uint256 _percent) external onlyOwner {
        require(protocolFeePercent <= 10000, "invalid fee percent");
        require(protocolFeePercent > 0, "invalid fee percent");
        protocolFeePercent = _percent;
    }

    function _distributeFees(
        address _nft,
        uint256 _tokenId,
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

        if (feeProvider == address(0)) {
            return sumFees;
        }

        // community fees
        address[] memory _addrs;
        uint256[] memory _rates;
        (_addrs, _rates) = IFeeProvider(feeProvider).getFees(_nft, _tokenId);
        for (uint256 i = 0; i < _addrs.length; i++) {
            fee = _price.mul(_rates[i]).div(10000);
            IERC20(_quoteToken).safeTransfer(_addrs[i], fee);
            sumFees = sumFees.add(fee);
        }
        return sumFees;
    }
}
