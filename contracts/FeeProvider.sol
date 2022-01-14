// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma abicoder v2;
import "@openzeppelin/contracts/access/Ownable.sol";

interface IProvider {
    function getFees(uint256 nftId)
        external
        view
        returns (address[] memory addrs, uint256[] memory rates);
}

contract FeeProvider is Ownable {
    mapping(address => address) public providers;
    mapping(address => Recipient) private feeRecipients;

    struct Recipient {
        address[] recipients;
        uint256[] rates;
    }

    event SetProvider(address _nft, address _provider);
    event SetRecipient(address _nft, address[] recipients, uint256[] rates);

    function setProvider(address _nft, address _provider) external onlyOwner {
        providers[_nft] = _provider;
        SetProvider(_nft, _provider);
    }

    function setRecipient(
        address _nft,
        address[] memory recipients,
        uint256[] memory rates
    ) external onlyOwner {
        uint256 sumRates = 0;
        for (uint256 i = 0; i < recipients.length; i++) {
            sumRates += rates[i];
            require(rates[i] < 10000, "invalid percent");
        }
        require(sumRates < 10000, "invalid percent");
        feeRecipients[_nft] = Recipient({recipients: recipients, rates: rates});
        emit SetRecipient(_nft, recipients, rates);
    }

    function getFees(address _nft, uint256 _tokenId)
        public
        view
        returns (address[] memory, uint256[] memory)
    {
        if (providers[_nft] == address(0)) {
            return (feeRecipients[_nft].recipients, feeRecipients[_nft].rates);
        }
        return IProvider(providers[_nft]).getFees(_tokenId);
    }
}
