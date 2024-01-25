// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract MockV3Aggregator {
    function latestRoundData() external pure returns (uint80, int256, uint256, uint256, uint80) {
        // return 2000 USD / ETH
        return (0, 2000e8, 0, 0, 0);
    }
}
