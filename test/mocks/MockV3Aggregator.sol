// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract MockV3Aggregator {
    int256 public price = 2000e8;

    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        // return 2000 USD / ETH
        return (0, price, 0, 0, 0);
    }
}
