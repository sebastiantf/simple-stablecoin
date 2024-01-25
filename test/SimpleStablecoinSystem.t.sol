// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {SimpleStablecoinSystem} from "../src/SimpleStablecoinSystem.sol";

contract SSDTest is Test {
    SimpleStablecoinSystem public sss;

    address alice = makeAddr("alice");

    function setUp() public {
        sss = new SimpleStablecoinSystem();
    }
}
