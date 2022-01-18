// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma abicoder v2;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";


interface IStakePool {
    function getUserCredit(address user) external view returns (uint256);
}

interface ILaunchpadMinter {
    function mint(address user, uint256 level) external;
}

contract ERC721NFTLaunchPad is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    struct Launch {
        uint256 price;
        uint256 maxSell;
        uint256 level;
        uint256 totalSold;
        uint256 creditPrice;
    }

    address public stakePool;
    address public minter;
    address public treasuryAddress;
    address public dealToken;

    // user address => launchIndex => ask
    mapping(address => mapping(uint256 => uint256)) boughtCount;
    Launch[] public launches;

    event Buy(address indexed user, uint256 _launchIndex);

    constructor(
        address _stakePool,
        address _minter,
        address _treasuryAddress,
        address _dealToken
    ) {
        stakePool = _stakePool;
        minter = _minter;
        treasuryAddress = _treasuryAddress;
        dealToken = _dealToken;
    }

    /**
     * @notice Add Launch
     * @param _price: price of launchpad
     * @param _maxSell: max sell
     * @param _level: level
     * @param _creditPrice: credit price
     */
    function addLaunch(
        uint256 _price,
        uint256 _maxSell,
        uint256 _level,
        uint256 _creditPrice
    ) external onlyOwner{
        launches.push(
            Launch({
                price: _price,
                maxSell: _maxSell,
                level: _level,
                creditPrice: _creditPrice,
                totalSold: 0
            })
        );
    }

    /**
     * @notice buy NFT
     * @param _launchIndex: launchpad index
     */
    function buy(uint256 _launchIndex) external nonReentrant {
        require(launches.length > _launchIndex, "ERC721NFTLaunchPad: Launch not found");
        _checkLimit(_launchIndex);
        Launch storage launch = launches[_launchIndex];
        ILaunchpadMinter(minter).mint(msg.sender, launch.level);
        boughtCount[msg.sender][_launchIndex]++;
        launch.totalSold++;
        IERC20(dealToken).safeTransferFrom(address(msg.sender), treasuryAddress, launch.price);
        Buy(msg.sender, _launchIndex);
    }

    function _checkLimit(uint256 _launchIndex) private {
        Launch memory launch = launches[_launchIndex];
        uint256 creditAmount = IStakePool(stakePool).getUserCredit(msg.sender);
        uint256 maxCanBuy = creditAmount / launch.creditPrice;
        require(
            maxCanBuy >= boughtCount[msg.sender][_launchIndex],
            "ERC721NFTLaunchPad: max can buy"
        );
        require(launch.totalSold < launch.maxSell, "ERC721NFTLaunchPad: sold out");
    }
}
