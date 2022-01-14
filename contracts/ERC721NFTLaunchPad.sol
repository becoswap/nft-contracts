// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma abicoder v2;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ICredit {
    function getCredit(address user) external view returns (uint256);
}

interface ILaunchpadMinter {
    function mint(address user, uint256 level);
}

contract ERC721NFTLaunchPad is ReentrancyGuard {
    struct Launch {
        uint256 price;
        uint256 maxSell;
        uint256 level;
        uint256 totalSold;
        uint256 creditPrice;
    }

    address public creditAdd;
    address public lauchpadMinter;

    // user address => launchIndex => ask
    mapping(address => mapping(uint256 => uint256)) boughtCount;
    Launch[] public launches;

    event Buy(address indexed user, uint256 _launchIndex);

    function addLaunch(
        uint256 _price,
        uint256 _maxSell,
        uint256 _level,
        uint256 _creditPrice
    ) external returns (uint256) {
        launches.push(
            Launch({
                price: _price,
                maxSell: _maxSell,
                level: _level,
                creditPrice: _creditPrice
            })
        );
        return launches.length - 1;
    }

    /**
     * @notice buy NFT
     * @param _launchIndex: launchpad index
     */
    function buy(uint256 _launchIndex) external {
        require(launches.length > _launchIndex, "launchpad not found");
        require(
            launches[_launchIndex].totalSold < launches[_launchIndex].maxSell,
            "sold out"
        );
        _checkCredit(_launchIndex);
        ILaunchpadMinter(lauchpadMinter).mint(
            msg.sender,
            launches[_launchIndex].level
        );
        boughtCount[msg.sender][_launchIndex]++;
        launches[_launchIndex].totalSold++;
        Buy(msg.sender, _launchIndex);
    }

    function _checkCredit(uint256 _launchIndex) private {
        uint256 creditAmount = ICredit(creditAdd).getCredit(msg.sender);
        uint256 maxCanBuy = creditAmount / launches[_launchIndex].creditPrice;
        require(
            maxCanBuy >= boughtCount[msg.sender][_launchIndex],
            "max can buy"
        );
    }
}
