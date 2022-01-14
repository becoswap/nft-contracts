// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma abicoder v2;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface ICredit {
    function getCredit(address user) external view returns (uint256);
}

interface ILaunchpadMinter {
    function mint(address user, uint256 level);
}

contract ERC721NFTLaunchPad is ReentrancyGuard, Ownable {
    struct Launch {
        uint256 price;
        uint256 maxSell;
        uint256 level;
        uint256 totalSold;
        uint256 creditPrice;
    }

    address public creditAddr;
    address public lauchpadMinter;
    address public treasuryAddress;
    address public dealToken;

    // user address => launchIndex => ask
    mapping(address => mapping(uint256 => uint256)) boughtCount;
    Launch[] public launches;

    event Buy(address indexed user, uint256 _launchIndex);

    constructor(
        address _creditAddr,
        address _lauchpadMinter,
        address _treasuryAddress,
        address _dealToken
    ) {
        creditAddr = _creditAddr;
        lauchpadMinter = _lauchpadMinter;
        treasuryAddress = _treasuryAddress;
        dealToken = _dealToken;
    }

    function addLaunch(
        uint256 _price,
        uint256 _maxSell,
        uint256 _level,
        uint256 _creditPrice
    ) external onlyOwner nonReentrant returns (uint256) {
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
    function buy(uint256 _launchIndex) external nonReentrant {
        _checkLimit(_launchIndex);
        Launch storage launch = launches[_launchIndex];
        ILaunchpadMinter(lauchpadMinter).mint(msg.sender, launch.level);
        boughtCount[msg.sender][_launchIndex]++;
        launch.totalSold++;
        IERC20(dealToken).safeTransferFrom(msg.sender, treasuryAddress, launch.price);
        Buy(msg.sender, _launchIndex);
    }

    function _checkLimit(uint256 _launchIndex) private {
        Launch memory launch = launches[_launchIndex];
        uint256 creditAmount = ICredit(creditAdd).getCredit(msg.sender);
        uint256 maxCanBuy = creditAmount / launch.creditPrice;
        require(
            maxCanBuy >= boughtCount[msg.sender][_launchIndex],
            "max can buy"
        );
        require(launch.totalSold < launch.maxSell, "sold out");
    }
}
