// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SafeMath} from "./SafeMath.sol";
import {SafeCast} from "./SafeCast.sol";
import {IERC20} from "../interfaces/IERC20.sol";

library PoolLibrary {
    using SafeMath for uint256;

    function quote(uint256 _amountA, uint256 _reserveA, uint256 _reserveB) public pure returns (uint256 amountB) {
        require(_amountA > 0, "Pool Library: Insufficient amount");
        require(_reserveA > 0 && _reserveB > 0, "Pool Library: Insufficient reservers");
        // (amountA * reserveB) / reserveA
        amountB = (_amountA.mul(_reserveB)).div(_reserveA);
    }

    function getAmountOut(int256 _amountIn, int256 _reserveIn, int256 _reserveOut, int256 _tick)
        public
        pure
        returns (int256 amountOut)
    {
        require(_reserveIn > 0 && _reserveOut > 0, "Pool Library: Insufficient reserves");

        if (_tick == 0) {
            int256 numenator = _reserveOut * _amountIn;
            int256 denominator = _reserveIn + _amountIn;
            amountOut = numenator / denominator;
        } else {
            int256 _sum = _reserveIn + _reserveOut;

            int256 coef_A = 4 * _tick;
            int256 coef_B = ((4 * _tick) * (_sum - _reserveIn - _amountIn - (2 * _reserveOut))) - _sum;
            int256 const_1 = (4 * _tick * _reserveOut) * (_reserveIn + _amountIn + _reserveOut - _sum);
            int256 const_2 = _sum * (_reserveOut - ((_sum * _sum) / (4 * (_reserveIn + _amountIn))));
            int256 coef_C = const_1 + const_2;

            int256 real_value = (coef_B * coef_B) - (4 * coef_A * coef_C);
            require(real_value > 0, "Pool Library : Invalid quadratic value");
            // coef-B should be in negitive
            require(coef_B < 0, "Pool Library : Invalid coef-B value");
            amountOut = (-coef_B - SafeCast.toInt256(SafeMath.sqrt(SafeCast.toUint256(real_value)))) / (2 * coef_A);
        }
    }

    function convertTo18Decimals(address _token, uint256 _amount) public view returns (uint256) {
        uint256 decimals = IERC20(_token).decimals();
        unchecked {
            if (decimals != 18) {
                if (decimals > 18) {
                    return _amount.div(10 ** (SafeMath.sub(decimals, 18)));
                } else {
                    return _amount.mul(10 ** (SafeMath.sub(18, decimals)));
                }
            } else {
                return _amount;
            }
        }
    }

    function convertToNative(address _token, uint256 _amount) public view returns (uint256) {
        uint256 decimals = IERC20(_token).decimals();
        unchecked {
            if (decimals != 18) {
                if (decimals > 18) {
                    return _amount.mul(10 ** (SafeMath.sub(decimals, 18)));
                } else {
                    return _amount.div(10 ** (SafeMath.sub(18, decimals)));
                }
            } else {
                return _amount;
            }
        }
    }

    function getCurrentPrice(address _tokenIn, address _tokenOut, address _pool) public view returns (uint256 price) {
        uint256 m_reserveIn = IERC20(_tokenIn).balanceOf(_pool); // 2000
        uint256 m_reserveOut = IERC20(_tokenOut).balanceOf(_pool); // 100

        // 1 tokenIn = X tokenOut, X=?
        // let dai in pool = 2000
        // eth in pool = 100
        // then for 1 dai we get 0.05 eth
        // for 1 eth we get 20 dai

        uint256 m_reserveInDecimals = IERC20(_tokenIn).decimals();
        uint256 m_reserveOutDecimals = IERC20(_tokenOut).decimals();

        if (m_reserveInDecimals <= m_reserveOutDecimals) {
            price = (m_reserveOut.mul(10 ** m_reserveOutDecimals)).div(m_reserveIn);
        } else {
            price = (m_reserveOut.mul(10 ** m_reserveInDecimals)).div(m_reserveIn);
        }

        // output price is in decimals of thier native decimal values
        // if IN = USDC, OUT = WETH
        // then for given X * 10**6 USDC gives price in tersm of Y * 10** 18 WETH
    }

    function getPriceRange(uint before_Price, uint _fee, uint _tick) public pure returns (uint256 low, uint256 high) {
        // more fee => more swap range
        // more tick(stable) => more swap range
        uint range = 0;
        low = 1;
        high = type(uint256).max;
    }

    function getAmountIn(int256 _amountOut, int256 _reserveIn, int256 _reserveOut, int256 _tick)
        public
        pure
        returns (int256 amountIn)
    {
        require(_reserveIn > 0 && _reserveOut > 0, "Pool Library: Insufficient liquidity");
        if (_tick == 0) {
            int256 numerator = _reserveIn * _amountOut;
            int256 denominator = _reserveOut - _amountOut;
            amountIn = (numerator / denominator);
        } else {
            int256 _sum = _reserveIn + _reserveOut;

            int256 coef_A = 4 * _tick;
            int256 coef_B = ((4 * _tick) * ((2 * _reserveIn) + _reserveOut - _amountOut - _sum)) + _sum;
            int256 const_1 = (4 * _tick * _reserveIn) * (_reserveOut - _amountOut - _sum + _reserveIn);
            int256 const_2 = _sum * (_reserveIn - ((_sum * _sum) / (4 * (_reserveOut - _amountOut))));
            int256 coef_C = const_1 + const_2;

            int256 real_value = (coef_B * coef_B) - (4 * coef_A * coef_C);
            require(real_value > 0, "Pool Library : Invalid quadratic value");
            // coef-B should be in positive
            require(coef_B > 0, "Pool Library : Invalid coef-B value");
            amountIn = (-coef_B + SafeCast.toInt256(SafeMath.sqrt(SafeCast.toUint256(real_value)))) / (2 * coef_A);
        }
    }

    function getAmountFee(uint256 _amountIn, uint256 _fee) public pure returns (uint256 amountIn) {
        require(_amountIn > 0, "Pool Library: Insufficient input");
        amountIn = (_amountIn.mul(_fee)).div(1000000);
    }
}
