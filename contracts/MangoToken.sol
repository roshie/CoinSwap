// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MangoToken is ERC20 {
    constructor() ERC20("Mango", "MGO") {
        _mint(msg.sender, 100000000000000000000000);
    }
}