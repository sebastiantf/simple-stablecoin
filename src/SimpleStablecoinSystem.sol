// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract SimpleStablecoinSystem {
    using SafeERC20 for IERC20;

    error MustBeGreaterThanZero();

    mapping(address user => mapping(address collateral => uint256 collateralBalance)) internal collateralBalances;

    modifier GreaterThanZero(uint256 _amount) {
        if (_amount <= 0) {
            revert MustBeGreaterThanZero();
        }
        _;
    }

    function depositCollateral(address _collateral, uint256 _amount) external GreaterThanZero(_amount) {
        collateralBalances[msg.sender][_collateral] += _amount;
        IERC20(_collateral).safeTransferFrom(msg.sender, address(this), _amount);
    }

    function collateralBalanceOf(address _user, address _collateral) public view returns (uint256) {
        return collateralBalances[_user][_collateral];
    }
}
