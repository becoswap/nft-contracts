// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestErc20 is ERC20 {
  constructor() ERC20("DEMO", "DEMO") {

  }

  function mint(uint256 amount) public {
    _mint(msg.sender, amount);
  }
}
