// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {SimpleStablecoin} from "../src/SimpleStablecoin.sol";
import {SimpleStablecoinSystem} from "../src/SimpleStablecoinSystem.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MockV3Aggregator} from "./mocks/MockV3Aggregator.sol";

contract SSDTest is Test {
    event CollateralDeposited(address indexed user, address indexed collateral, uint256 amount);
    event CollateralRedeemed(address indexed user, address indexed collateral, uint256 amount);
    event SSDMinted(address indexed user, uint256 amount);
    event SSDBurned(address indexed user, uint256 amount);

    SimpleStablecoin public ssd;
    SimpleStablecoinSystem public sss;
    ERC20Mock public weth = new ERC20Mock();
    MockV3Aggregator public mockV3AggregatorWeth = new MockV3Aggregator();

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        address[] memory collaterals = new address[](1);
        address[] memory priceFeeds = new address[](1);
        collaterals[0] = address(weth);
        priceFeeds[0] = address(mockV3AggregatorWeth);

        ssd = new SimpleStablecoin();
        sss = new SimpleStablecoinSystem(ssd, collaterals, priceFeeds);

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

    function test_priceFeeds() public {
        assertEq(sss.priceFeeds(address(weth)), address(mockV3AggregatorWeth));
    }

    function test_liquidationThreshold() public {
        assertEq(sss.LIQUIDATION_THRESHOLD(), 80);
        assertEq(sss.LIQUIDATION_PRECISION(), 100);
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

        // deposit collateral
        uint256 collateralAmount = 0.5 ether;
        weth.approve(address(sss), collateralAmount);
        sss.depositCollateral(address(weth), collateralAmount);

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

    function test_mintSSDRevertsIfZero() public {
        uint256 ssdAmount = 0;
        vm.expectRevert(SimpleStablecoinSystem.MustBeGreaterThanZero.selector);
        sss.mintSSD(ssdAmount);
    }

    function test_mintSSDRevertsIfInsufficientHealthFactor() public {
        vm.startPrank(alice);

        // deposit collateral
        uint256 collateralAmount = 0.5 ether;
        weth.approve(address(sss), collateralAmount);
        sss.depositCollateral(address(weth), collateralAmount);
        assertEq(sss.totalCollateralValueInUSD(alice), 1000e18); // 1000 USD
        // mint SSD - 1000 * 81% = 810
        uint256 ssdAmount = 810e18;
        vm.expectRevert(SimpleStablecoinSystem.InsufficientHealthFactor.selector);
        sss.mintSSD(ssdAmount);

        vm.stopPrank();
    }

    /* tokenToUSD() */
    function test_tokenToUSD() public {
        assertEq(sss.tokenToUSD(address(weth), 1 ether), 2000e18); // 1 ETH = 2000 USD
        assertEq(sss.tokenToUSD(address(weth), 0.5 ether), 1000e18); // 0.5 ETH = 1000 USD
    }

    /* totalCollateralValueInUSD() */
    function test_totalCollateralValueInUSD() public {
        vm.startPrank(alice);

        // deposit collateral
        uint256 collateralAmount = 0.5 ether;
        weth.approve(address(sss), collateralAmount);
        sss.depositCollateral(address(weth), collateralAmount);

        assertEq(sss.totalCollateralValueInUSD(alice), 1000e18);

        // deposit more collateral
        collateralAmount = 0.5 ether;
        weth.approve(address(sss), collateralAmount);
        sss.depositCollateral(address(weth), collateralAmount);

        assertEq(sss.totalCollateralValueInUSD(alice), 2000e18);

        vm.stopPrank();
    }

    /* healthFactor() */
    function test_healthFactor() public {
        vm.startPrank(alice);

        // deposit collateral
        uint256 collateralAmount = 0.5 ether;
        weth.approve(address(sss), collateralAmount);
        sss.depositCollateral(address(weth), collateralAmount);
        assertEq(sss.totalCollateralValueInUSD(alice), 1000e18); // 1000 USD
        // mint SSD - 1000 * 80% = 800
        uint256 ssdAmount = 800e18;
        sss.mintSSD(ssdAmount);

        // (((totalCollateralValueInUSD * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION) * 1e18) / totalSSDMinted;
        // (((1000 * 80) / 100) * 1e18) / 800 = 1e18
        assertEq(sss.healthFactor(alice), 1e18);

        vm.stopPrank();
    }

    /* redeemCollateral() */
    function test_redeemCollateral() public {
        vm.startPrank(alice);

        // deposit collateral
        uint256 collateralAmount = 0.5 ether;
        weth.approve(address(sss), collateralAmount);
        sss.depositCollateral(address(weth), collateralAmount);

        // redeem collateral
        uint256 redeemAmount = 0.25 ether;
        vm.expectEmit(true, true, true, true);
        emit CollateralRedeemed(alice, address(weth), redeemAmount);
        sss.redeemCollateral(address(weth), redeemAmount);

        // final balances
        assertEq(sss.collateralBalanceOf(alice, address(weth)), 0.25 ether);
        assertEq(weth.balanceOf(alice), 0.75 ether);
        assertEq(weth.balanceOf(address(sss)), 0.25 ether);

        vm.stopPrank();
    }

    function test_redeemCollateralRevertsIfUnsupported() public {
        ERC20Mock unsupported = new ERC20Mock();
        uint256 redeemAmount = 0.25 ether;
        vm.expectRevert(SimpleStablecoinSystem.UnsupportedCollateral.selector);
        sss.redeemCollateral(address(unsupported), redeemAmount);
    }

    function test_redeemCollateralRevertsIfInsufficientHealthFactor() public {
        vm.startPrank(alice);

        // deposit collateral
        uint256 collateralAmount = 0.5 ether;
        weth.approve(address(sss), collateralAmount);
        sss.depositCollateral(address(weth), collateralAmount);
        assertEq(sss.totalCollateralValueInUSD(alice), 1000e18); // 1000 USD
        // mint SSD - 1000 * 80% = 800
        uint256 ssdAmount = 800e18;
        sss.mintSSD(ssdAmount);

        // health factor = 1e18
        assertEq(sss.healthFactor(alice), 1e18);

        // redeem collateral
        uint256 redeemAmount = 0.25 ether;
        vm.expectRevert(SimpleStablecoinSystem.InsufficientHealthFactor.selector);
        sss.redeemCollateral(address(weth), redeemAmount);

        vm.stopPrank();
    }

    /* burnSSD() */
    function test_burnSSD() public {
        vm.startPrank(alice);

        // deposit collateral
        uint256 collateralAmount = 0.5 ether;
        weth.approve(address(sss), collateralAmount);
        sss.depositCollateral(address(weth), collateralAmount);

        // mint SSD
        uint256 ssdAmount = 100;
        sss.mintSSD(ssdAmount);

        // burn SSD
        uint256 burnAmount = 50;
        ssd.approve(address(sss), burnAmount);
        vm.expectEmit(true, true, true, true);
        emit SSDBurned(alice, burnAmount);
        sss.burnSSD(burnAmount);

        // final balances
        assertEq(sss.ssdMintedOf(alice), 50);
        assertEq(ssd.balanceOf(alice), 50);

        vm.stopPrank();
    }

    function test_burnSSDRevertsIfZero() public {
        uint256 burnAmount = 0;
        vm.expectRevert(SimpleStablecoinSystem.MustBeGreaterThanZero.selector);
        sss.burnSSD(burnAmount);
    }

    /* tokenFromUSD() */
    function test_tokenFromUSD() public {
        assertEq(sss.tokenFromUSD(address(weth), 2000e18), 1 ether); // 2000 USD = 1 ETH
        assertEq(sss.tokenFromUSD(address(weth), 1000e18), 0.5 ether); // 1000 USD = 0.5 ETH
    }

    /* liquidate() */
    function test_liquidateRevertsIfSufficientHealthFactor() public {
        vm.startPrank(alice);

        // deposit collateral
        uint256 collateralAmount = 0.5 ether;
        weth.approve(address(sss), collateralAmount);
        sss.depositCollateral(address(weth), collateralAmount);
        assertEq(sss.totalCollateralValueInUSD(alice), 1000e18); // 1000 USD
        // mint SSD - 1000 * 80% = 800
        uint256 ssdAmount = 800e18;
        sss.mintSSD(ssdAmount);

        // health factor = 1e18
        assertEq(sss.healthFactor(alice), 1e18);

        // liquidate
        uint256 liquidateAmount = 0.25 ether;
        vm.expectRevert(SimpleStablecoinSystem.SufficientHealthFactor.selector);
        sss.liquidate(alice, address(weth), liquidateAmount);

        vm.stopPrank();
    }

    function test_liquidate() public {
        vm.startPrank(alice);

        // deposit collateral
        uint256 collateralAmount = 1 ether;
        weth.approve(address(sss), collateralAmount);
        sss.depositCollateral(address(weth), collateralAmount);
        assertEq(sss.totalCollateralValueInUSD(alice), 2000e18); // 2000 USD
        // mint SSD - 2000 * 80% = 1600
        uint256 ssdAmount = 1600e18;
        sss.mintSSD(ssdAmount);

        // health factor = 2000 * 80% / 1600 = 1
        assertEq(sss.healthFactor(alice), 1e18);

        // decrease ETH price to 1700 USD
        mockV3AggregatorWeth.setPrice(1700e8);

        // health factor = 1700 * 80% / 1600 = 0.85e18
        uint256 newHealthFactor = sss.healthFactor(alice);
        assertEq(newHealthFactor, 0.85e18);

        // TODO: improve calculation. this doesn't make health factor 1
        // 1700 * 80% / x = 1
        // x = 1700 * 80% / 1 = 1360
        // 1600 - 1360 = 240 SSD needs to be burned
        // 240 / 1700 = 0.1411764706 ETH needs to be liquidated
        // 0.1411764706 + 5% = 0.1482352941 ETH will be liquidated including bonus
        uint256 ssdValueInCollateral = sss.tokenFromUSD(address(weth), 240e18);
        uint256 liquidationBonus = (ssdValueInCollateral * sss.LIQUIDATION_BONUS()) / sss.LIQUIDATION_PRECISION();
        ssdValueInCollateral += liquidationBonus;

        // liquidate
        uint256 liquidateAmount = 240e18;
        // transfer liquidateAmount SSD from alice to bob, only for testing because we can't mint SSD
        ssd.transfer(bob, liquidateAmount);
        vm.stopPrank();

        vm.startPrank(bob);
        ssd.approve(address(sss), liquidateAmount);
        sss.liquidate(alice, address(weth), liquidateAmount);
        vm.stopPrank();

        // final balances
        assertGt(sss.healthFactor(alice), newHealthFactor); // improves health factor
        assertEq(sss.collateralBalanceOf(alice, address(weth)), collateralAmount - ssdValueInCollateral);
        assertEq(weth.balanceOf(alice), 0);
        assertEq(weth.balanceOf(address(sss)), collateralAmount - ssdValueInCollateral);
        assertEq(sss.ssdMintedOf(alice), ssdAmount - liquidateAmount);
        assertEq(ssd.balanceOf(alice), ssdAmount - liquidateAmount); // because we transferred 240 SSD to bob
    }
}
