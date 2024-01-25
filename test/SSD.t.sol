// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {SimpleStablecoin} from "../src/SSD.sol";

contract SSDTest is Test {
    SimpleStablecoin public ssd;

    address alice = makeAddr("alice");

    function setUp() public {
        ssd = new SimpleStablecoin();
    }

    function test_NameSymbol() public {
        assertEq(ssd.name(), "SimpleStablecoin");
        assertEq(ssd.symbol(), "SSD");
    }

    function test_Mint() public {
        assertEq(ssd.balanceOf(alice), 0);

        ssd.mint(alice, 100);
        assertEq(ssd.balanceOf(alice), 100);
    }
}
