// contracts/GLDToken.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract CrazySharo is ERC20 {
    constructor() ERC20("CrazySharo", "Sharo") {
        _mint(msg.sender, 10000000000 * (10 ** 18));
    }
}
