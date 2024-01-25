// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract SimpleStablecoin is ERC20 {
    constructor() ERC20("SimpleStablecoin", "SSD") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
