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

    function test_OnlyOwnerCanMint() public {
        assertEq(ssd.balanceOf(alice), 0);

        ssd.mint(alice, 100);
        assertEq(ssd.balanceOf(alice), 100);

        vm.startPrank(alice);
        vm.expectRevert();
        ssd.mint(alice, 100);
        vm.stopPrank();
    }

    function test_Burn() public {
        assertEq(ssd.balanceOf(alice), 0);

        ssd.mint(alice, 100);
        assertEq(ssd.balanceOf(alice), 100);

        vm.startPrank(alice);
        ssd.burn(50);
        assertEq(ssd.balanceOf(alice), 50);
        vm.stopPrank();
    }

    function test_Owner() public {
        assertEq(ssd.owner(), address(this));

        ssd.transferOwnership(alice);

        assertEq(ssd.owner(), alice);
    }
}
