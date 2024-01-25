// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {SimpleStablecoinSystem} from "../src/SimpleStablecoinSystem.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract SSDTest is Test {
    SimpleStablecoinSystem public sss;
    ERC20Mock public weth = new ERC20Mock();

    address alice = makeAddr("alice");

    function setUp() public {
        address[] memory collaterals = new address[](1);
        collaterals[0] = address(weth);

        sss = new SimpleStablecoinSystem(collaterals);

        weth.mint(alice, 1 ether);
    }

    function test_supportedCollaterals() public {
        assertEq(sss.supportedCollaterals(address(weth)), true);
    }

    /* depositCollateral() */
    function test_depositCollateral() public {
        vm.startPrank(alice);

        // initial balances
        assertEq(sss.collateralBalanceOf(alice, address(weth)), 0);
        assertEq(weth.balanceOf(alice), 1 ether);
        assertEq(weth.balanceOf(address(sss)), 0);

        // deposit collateral
        uint256 collateralAmount = 0.5 ether;
        weth.approve(address(sss), collateralAmount);
        sss.depositCollateral(address(weth), collateralAmount);

        // final balances
        assertEq(sss.collateralBalanceOf(alice, address(weth)), collateralAmount);
        assertEq(weth.balanceOf(alice), 0.5 ether);
        assertEq(weth.balanceOf(address(sss)), 0.5 ether);

        vm.stopPrank();
    }

    function test_depositCollateralRevertsIfZero() public {
        uint256 collateralAmount = 0;
        vm.expectRevert(SimpleStablecoinSystem.MustBeGreaterThanZero.selector);
        sss.depositCollateral(address(weth), collateralAmount);
    }
}
