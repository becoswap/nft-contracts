// SPDX-License-Identifier: MIT

pragma solidity =0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract VoteNFT is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IERC20 public krc20;
    address public feeAddress;
    uint256 MIN_VOTE = 1 ether;

    event Voted(address voter, address nft, uint256 tokenId, uint256 votes);

    constructor(address _krc20, address _feeAddress) Ownable() {
        krc20 = IERC20(_krc20);
        feeAddress = _feeAddress;
    }

    function vote(
        address _nft,
        uint256 _tokenId,
        uint256 _votes
    ) public {
        require(_votes >= MIN_VOTE, "min vote");
        IERC721 nft = IERC721(_nft);
        uint256 half = _votes.div(2);
        krc20.safeTransferFrom(_msgSender(), nft.ownerOf(_tokenId), half);
        krc20.safeTransferFrom(_msgSender(), feeAddress, half);
        emit Voted(_msgSender(), _nft, _tokenId, _votes);
    }

    function emergencyWithdrawEther() public onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    function emergencyWithdrawErc20(address tokenAddress) public onlyOwner {
        IERC20 token = IERC20(tokenAddress);
        token.safeTransfer(_msgSender(), token.balanceOf(address(this)));
    }

    function setFeeAddress(address _feeAddress) public onlyOwner {
        feeAddress = _feeAddress;
    }
}
