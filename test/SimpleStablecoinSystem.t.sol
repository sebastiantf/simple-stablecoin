// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {SimpleStablecoin} from "../src/SimpleStablecoin.sol";
import {SimpleStablecoinSystem} from "../src/SimpleStablecoinSystem.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract SSDTest is Test {
    event CollateralDeposited(address indexed user, address indexed collateral, uint256 amount);
    event SSDMinted(address indexed user, uint256 amount);

    SimpleStablecoin public ssd;
    SimpleStablecoinSystem public sss;
    ERC20Mock public weth = new ERC20Mock();

    address alice = makeAddr("alice");

    function setUp() public {
        address[] memory collaterals = new address[](1);
        collaterals[0] = address(weth);

        ssd = new SimpleStablecoin();
        sss = new SimpleStablecoinSystem(ssd, collaterals);

        ssd.transferOwnership(address(sss));

        weth.mint(alice, 1 ether);
    }

    function test_ssd() public {
        assertEq(address(sss.ssd()), address(ssd));
    }

    function test_isCollateralSupported() public {
        assertEq(sss.isCollateralSupported(address(weth)), true);
    }

    function test_supportedCollaterals() public {
        assertEq(sss.supportedCollaterals(0), address(weth));
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
        vm.expectEmit(true, true, true, true);
        emit CollateralDeposited(alice, address(weth), collateralAmount);
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

    function test_depositCollateralRevertsIfUnsupported() public {
        ERC20Mock unsupported = new ERC20Mock();
        uint256 collateralAmount = 0.5 ether;
        vm.expectRevert(SimpleStablecoinSystem.UnsupportedCollateral.selector);
        sss.depositCollateral(address(unsupported), collateralAmount);
    }

    /* mintSSD() */
    function test_mintSSD() public {
        vm.startPrank(alice);

        // initial balances
        assertEq(sss.ssdMintedOf(alice), 0);
        assertEq(ssd.balanceOf(alice), 0);

        // mint SSD
        uint256 ssdAmount = 100;
        vm.expectEmit(true, true, true, true);
        emit SSDMinted(alice, ssdAmount);
        sss.mintSSD(ssdAmount);

        // final balances
        assertEq(sss.ssdMintedOf(alice), ssdAmount);
        assertEq(ssd.balanceOf(alice), ssdAmount);

        vm.stopPrank();
    }
}
