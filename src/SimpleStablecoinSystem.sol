// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {SimpleStablecoin} from "./SimpleStablecoin.sol";

contract SimpleStablecoinSystem {
    using SafeERC20 for IERC20;

    error MustBeGreaterThanZero();
    error UnsupportedCollateral();

    event CollateralDeposited(address indexed user, address indexed collateral, uint256 amount);

    SimpleStablecoin public ssd;
    mapping(address collateral => bool isSupported) public supportedCollaterals;
    mapping(address user => mapping(address collateral => uint256 collateralBalance)) internal collateralBalances;

    modifier GreaterThanZero(uint256 _amount) {
        if (_amount <= 0) {
            revert MustBeGreaterThanZero();
        }
        _;
    }

    modifier onlySupportedCollateral(address _collateral) {
        if (!supportedCollaterals[_collateral]) {
            revert UnsupportedCollateral();
        }
        _;
    }

    constructor(SimpleStablecoin _ssd, address[] memory _collaterals) {
        ssd = _ssd;
        for (uint256 i = 0; i < _collaterals.length; i++) {
            supportedCollaterals[_collaterals[i]] = true;
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

    function collateralBalanceOf(address _user, address _collateral) public view returns (uint256) {
        return collateralBalances[_user][_collateral];
    }
}
