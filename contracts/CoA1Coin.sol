// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract CoA1Coin is ERC20 {
    constructor() ERC20("CoA1Coin", "CoA1$") {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

    function requestTokens(address to) public {
        mint(to, 1 * 10**18);
    }
}
