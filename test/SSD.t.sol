// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {SimpleStablecoin} from "../src/SSD.sol";

contract SSDTest is Test {
    SimpleStablecoin public ssd;

    function setUp() public {
        ssd = new SimpleStablecoin();
    }

    function test_NameSymbol() public {
        assertEq(ssd.name(), "SimpleStablecoin");
        assertEq(ssd.symbol(), "SSD");
    }
}
