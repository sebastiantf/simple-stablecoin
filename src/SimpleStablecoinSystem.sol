// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import {SimpleStablecoin} from "./SimpleStablecoin.sol";

contract SimpleStablecoinSystem {
    using SafeERC20 for IERC20;

    error MustBeGreaterThanZero();
    error UnsupportedCollateral();
    error InsufficientHealthFactor();
    error SufficientHealthFactor();

    event CollateralDeposited(address indexed user, address indexed collateral, uint256 amount);
    event CollateralRedeemed(address indexed user, address indexed collateral, uint256 amount);
    event SSDMinted(address indexed user, uint256 amount);
    event SSDBurned(address indexed user, uint256 amount);
    event Liquidated(address indexed user, address indexed collateral, uint256 collateralAmount, uint256 ssdAmount);

    // Liquidation threshold is 80%
    // If loan value raises above 80% of collateral value, the loan can be liquidated
    uint256 public constant LIQUIDATION_THRESHOLD = 80;
    uint256 public constant LIQUIDATION_BONUS = 5;
    uint256 public constant LIQUIDATION_PRECISION = 100;

    SimpleStablecoin public ssd;
    address[] public supportedCollaterals;
    mapping(address collateral => bool isSupported) public isCollateralSupported;
    mapping(address collateral => address priceFeed) public priceFeeds;
    mapping(address user => mapping(address collateral => uint256 collateralBalance)) internal collateralBalances;
    mapping(address user => uint256 ssdMinted) internal ssdMinted;

    modifier GreaterThanZero(uint256 _amount) {
        if (_amount <= 0) {
            revert MustBeGreaterThanZero();
        }
        _;
    }

    modifier onlySupportedCollateral(address _collateral) {
        if (!isCollateralSupported[_collateral]) {
            revert UnsupportedCollateral();
        }
        _;
    }

    constructor(SimpleStablecoin _ssd, address[] memory _collaterals, address[] memory _priceFeeds) {
        ssd = _ssd;
        supportedCollaterals = _collaterals;
        for (uint256 i = 0; i < _collaterals.length; i++) {
            priceFeeds[_collaterals[i]] = _priceFeeds[i];
            isCollateralSupported[_collaterals[i]] = true;
        }
    }

    function depositCollateral(address _collateral, uint256 _amount)
        external
        GreaterThanZero(_amount)
        onlySupportedCollateral(_collateral)
    {
        collateralBalances[msg.sender][_collateral] += _amount;
        IERC20(_collateral).safeTransferFrom(msg.sender, address(this), _amount);
        emit CollateralDeposited(msg.sender, _collateral, _amount);
    }

    function mintSSD(uint256 _amount) external GreaterThanZero(_amount) {
        ssdMinted[msg.sender] += _amount;
        _revertIfInsufficientHealthFactor(msg.sender);
        ssd.mint(msg.sender, _amount);
        emit SSDMinted(msg.sender, _amount);
    }

    function redeemCollateral(address _collateral, uint256 _amount) external onlySupportedCollateral(_collateral) {
        collateralBalances[msg.sender][_collateral] -= _amount;
        _revertIfInsufficientHealthFactor(msg.sender);
        IERC20(_collateral).safeTransfer(msg.sender, _amount);
        emit CollateralRedeemed(msg.sender, _collateral, _amount);
    }

    function burnSSD(uint256 _amount) external GreaterThanZero(_amount) {
        ssdMinted[msg.sender] -= _amount;
        _revertIfInsufficientHealthFactor(msg.sender); // probably not needed
        ssd.burnFrom(msg.sender, _amount);
        emit SSDBurned(msg.sender, _amount);
    }

    function liquidate(address _user, address _collateral, uint256 _ssdAmount) external {
        uint256 currentHealthFactor = healthFactor(_user);
        if (currentHealthFactor >= 1e18) revert SufficientHealthFactor();

        // get SSD value in collateral
        uint256 ssdValueInCollateral = tokenFromUSD(_collateral, _ssdAmount);
        // add liquidation bonus
        uint256 liquidationBonus = (ssdValueInCollateral * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;
        ssdValueInCollateral += liquidationBonus;

        // redeem collateral from user
        collateralBalances[_user][_collateral] -= ssdValueInCollateral;
        IERC20(_collateral).safeTransfer(msg.sender, ssdValueInCollateral);
        emit CollateralRedeemed(_user, _collateral, ssdValueInCollateral);

        // burn SSD from liquidator
        ssdMinted[_user] -= _ssdAmount;
        ssd.burnFrom(msg.sender, _ssdAmount);
        emit SSDBurned(_user, _ssdAmount);

        // check health factor improved
        uint256 newHealthFactor = healthFactor(_user);
        if (newHealthFactor <= currentHealthFactor) revert InsufficientHealthFactor();

        emit Liquidated(_user, _collateral, ssdValueInCollateral, _ssdAmount);
    }

    function collateralBalanceOf(address _user, address _collateral) public view returns (uint256) {
        return collateralBalances[_user][_collateral];
    }

    function ssdMintedOf(address _user) public view returns (uint256) {
        return ssdMinted[_user];
    }

    function healthFactor(address user) public view returns (uint256) {
        uint256 totalSSDMinted = ssdMintedOf(user);
        // if no SSD minted, health factor is max, else division by zero
        if (totalSSDMinted == 0) return type(uint256).max;

        uint256 _totalCollateralValueInUSD = totalCollateralValueInUSD(user);
        // health factor = (total collateral value in USD * liquidation threshold) / (total SSD value in USD)
        // adding 1e18 to keep precision after division with 1e18
        return (((_totalCollateralValueInUSD * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION) * 1e18) / totalSSDMinted;
    }

    function totalCollateralValueInUSD(address user) public view returns (uint256) {
        uint256 _totalCollateralValueInUSD;
        for (uint256 i = 0; i < supportedCollaterals.length; i++) {
            address collateral = supportedCollaterals[i];
            uint256 collateralBalance = collateralBalances[user][collateral];
            uint256 collateralValueInUSD = tokenToUSD(collateral, collateralBalance);
            _totalCollateralValueInUSD += collateralValueInUSD;
        }
        return _totalCollateralValueInUSD;
    }

    function tokenToUSD(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        // USD price feed has 8 decimals
        // We scale it to 18 decimals: 1e8 * 1e10 / 1e18 = 1e18
        // TODO: generalize precision
        // token value in usd = price * amount
        return ((uint256(price) * 1e10) * amount) / 1e18;
    }

    function tokenFromUSD(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        // USD price feed has 8 decimals
        // We scale it to 18 decimals: 1e18 * 1e18 / 1e18 = 1e18
        // TODO: generalize precision
        // token amount = amount / price
        return (amount * 1e18) / (uint256(price) * 1e10);
    }

    function _revertIfInsufficientHealthFactor(address _user) internal view {
        if (healthFactor(_user) < 1e18) revert InsufficientHealthFactor();
    }
}
