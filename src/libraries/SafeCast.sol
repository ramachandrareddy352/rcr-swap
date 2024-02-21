// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library SafeCast {
    function toInt256(uint256 value) internal pure returns (int256) {
        require(value < uint256(type(int256).max), "SafeCast : Invalid number");
        return int256(value);
    }

    function toUint256(int256 value) internal pure returns (uint256) {
        require(value < type(int256).max && value > type(int256).min, "SafeCast : Invalid values");
        if (value < 0) {
            value = -(value);
        }
        return uint256(value);
    }
}
