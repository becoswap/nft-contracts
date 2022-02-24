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
    uint256 public protocolFeePercent = 250;

    uint256 public MAX_FEE = 500; // 5%
    uint256 public MAX_TOTAL_FEE = 1000; // 10%

    constructor(
        address _feeProvider,
        address _recipient,
        uint256 _feePercent
    ) {
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
        require(_percent <= MAX_FEE, "max_fee");
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
        uint256 sumRates = 0;
        for (uint256 i = 0; i < _addrs.length; i++) {
            if (_addrs[i] != address(0)) {
                sumRates = sumRates.add(_rates[i]);
                if (sumRates > MAX_TOTAL_FEE) {
                    return sumFees;
                }
                fee = _price.mul(_rates[i]).div(10000);
                IERC20(_quoteToken).safeTransfer(_addrs[i], fee);
                sumFees = sumFees.add(fee);
            }
        }
        return sumFees;
    }
}
