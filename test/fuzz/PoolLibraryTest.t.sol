// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "forge-std/Vm.sol";

import {ERC20} from "../helper/ERC20.sol";
import {IERC20} from "../helper/IERC20.sol";

import {SafeMath} from "../../src/libraries/SafeMath.sol";
import {SafeCast} from "../../src/libraries/SafeCast.sol";
import {PoolLibrary} from "../helper/PoolLibrary.sol";

contract PoolLibraryTest is Test {
    PoolLibrary poolLibrary;

    ERC20 USDC;
    ERC20 DAI;

    function setUp() public {
        poolLibrary = new PoolLibrary();
        DAI = new ERC20("DAI", "DAI", 18);
        USDC = new ERC20("USDC", "USDC", 6);
    }

    function test_decimals() external {
        assertEq(DAI.decimals(), 18);
        assertEq(USDC.decimals(), 6);
    }

    function test_quote(uint256 _amountA, uint256 _reserveA, uint256 _reserveB) external {
        // bound b/w 1 to 1 trillion
        vm.assume(_reserveA >= 1 && _reserveA <= 1e30);
        vm.assume(_reserveB >= 1 && _reserveB <= 1e30);
        vm.assume(_amountA >= 1 && _amountA <= _reserveA);

        uint256 amountB = (_amountA * _reserveB) / _reserveA;

        assertEq(poolLibrary.quote(_amountA, _reserveA, _reserveB), amountB);
    }

    function test_getAmountOut(uint256 _amountIn, uint256 _reserveIn, uint256 _reserveOut) external {
        vm.assume(_reserveIn >= 1 && _reserveIn <= 1e27);
        vm.assume(_reserveOut >= 1 && _reserveOut <= 1e27);
        vm.assume(_amountIn >= 1 && _amountIn < _reserveIn);

        if (_reserveIn >= _reserveOut) {
            if (_reserveIn + _amountIn >= _reserveOut) {
                assertLe(poolLibrary.getAmountOut(_amountIn, _reserveIn, _reserveOut), _amountIn);
            } else {
                assertGe(poolLibrary.getAmountOut(_amountIn, _reserveIn, _reserveOut), _amountIn);
            }
        } else {
            if (_reserveIn + _amountIn >= _reserveOut) {
                assertLe(poolLibrary.getAmountOut(_amountIn, _reserveIn, _reserveOut), _amountIn);
            } else {
                assertGe(poolLibrary.getAmountOut(_amountIn, _reserveIn, _reserveOut), _amountIn);
            }
        }
    }

    function test_getAmountIn(uint256 _amountOut, uint256 _reserveIn, uint256 _reserveOut) external {
        vm.assume(_reserveIn >= 1 && _reserveIn <= 1e27);
        vm.assume(_reserveOut >= 1 && _reserveOut <= 1e27);
        vm.assume(_amountOut >= 1 && _amountOut < _reserveOut);

        if (_reserveIn >= _reserveOut) {
            if (_reserveOut - _amountOut >= _reserveIn) {
                assertLe(poolLibrary.getAmountIn(_amountOut, _reserveIn, _reserveOut), _amountOut);
            } else {
                assertGe(poolLibrary.getAmountIn(_amountOut, _reserveIn, _reserveOut), _amountOut);
            }
        } else {
            if (_reserveOut - _amountOut >= _reserveIn) {
                assertLe(poolLibrary.getAmountIn(_amountOut, _reserveIn, _reserveOut), _amountOut);
            } else {
                assertGe(poolLibrary.getAmountIn(_amountOut, _reserveIn, _reserveOut), _amountOut);
            }
        }
    }
}
