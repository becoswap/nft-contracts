pragma solidity =0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IRobotCore is IERC721 {
    function isPregnant(uint256 _robotId) external view returns (bool);
}
