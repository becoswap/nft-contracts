// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
pragma abicoder v2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract ERC721Operator is ERC721, Ownable {
    mapping(uint256 => address) _tokenOperator;
    mapping(address => mapping(address => bool)) _operatorUpdates;
    event SetOperator(uint256 tokenId, address operator);
    event SetOperatorUpdates(address owner, address operator, bool approved);

    modifier onlyOperatorOrTokenOwner(uint256 tokenId) {
        require(
            _isOperator(_msgSender(), tokenId) ||
                _isApprovedOrOwner(_msgSender(), tokenId),
            "Land: only operator or owner"
        );
        _;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, tokenId);
        _tokenOperator[tokenId] = address(0x0);
        emit SetOperator(tokenId, address(0x0));
    }

    function isOperator(address _operator, uint256 tokenId)
        external
        view
        returns (bool)
    {
        return _isOperator(_operator, tokenId);
    }

    function isOperatorUpdates(address owner, address _operator)
        external
        view
        returns (bool)
    {
        return _operatorUpdates[owner][_operator];
    }

    function _isOperator(address _operator, uint256 tokenId)
        internal
        view
        returns (bool)
    {
        address owner = ownerOf(tokenId);
        return
            owner == _operator ||
            _tokenOperator[tokenId] == _operator ||
            _operatorUpdates[owner][_operator];
    }

     function setOperator(uint256 tokenId, address _operator)
        public
        onlyOperatorOrTokenOwner(tokenId)
    {
        require(_operator != address(0x0), "zero address");
        require(_tokenOperator[tokenId] != _operator, "not change");
        _tokenOperator[tokenId] = _operator;
        emit SetOperator(tokenId, _operator);
    }

    function setOperatorUpdates(address _operator, bool approved) external {
        require(_operator != address(0x0), "zero address");
        require(_operator != _msgSender(), "same sender");
        _operatorUpdates[_msgSender()][_operator] = approved;
        emit SetOperatorUpdates(_msgSender(), _operator, approved);
    }

    function setManyOperator(uint256[] calldata tokenIds, address _operator)
        external
    {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            setOperator(tokenIds[i], _operator);
        }
    }
}
