// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SafeMath} from "../../src/libraries/SafeMath.sol";
import {SafeCast} from "../../src/libraries/SafeCast.sol";
import {IERC20} from "../../src/interfaces/IERC20.sol";

contract PoolLibrary {
    using SafeMath for uint256;

    function quote(uint256 _amountA, uint256 _reserveA, uint256 _reserveB) public pure returns (uint256 amountB) {
        require(_amountA > 0, "Pool Library: Insufficient amount");
        require(_reserveA > 0 && _reserveB > 0, "Pool Library: Insufficient reservers");
        // (amountA * reserveB) / reserveA
        amountB = (_amountA.mul(_reserveB)).div(_reserveA);
    }

    function getAmountOut(uint256 _amountIn, uint256 _reserveIn, uint256 _reserveOut)
        public
        pure
        returns (uint256 amountOut)
    {
        require(_reserveIn > 0 && _reserveOut > 0, "Pool Library: Insufficient reserves");
        require(_amountIn < _reserveIn, "Pool Library : Invalid amountOut");

        uint256 numenator = _reserveOut.mul(_amountIn);
        uint256 denominator = _reserveIn.add(_amountIn);
        amountOut = numenator.div(denominator);
    }

    function getAmountIn(uint256 _amountOut, uint256 _reserveIn, uint256 _reserveOut)
        public
        pure
        returns (uint256 amountIn)
    {
        require(_reserveIn > 0 && _reserveOut > 0, "Pool Library: Insufficient liquidity");
        require(_amountOut < _reserveOut, "Pool Library : Invalid amountOut");

        uint256 numerator = _reserveIn.mul(_amountOut);
        uint256 denominator = _reserveOut.sub(_amountOut);
        amountIn = numerator.div(denominator);
    }

    function getCurrentPrice(uint256 _reserveIn, uint256 _reserveOut, uint256 _reserveInDecimals)
        public
        pure
        returns (uint256 price)
    {
        // 1 tokenIn = X tokenOut, X=?
        // let dai in pool = 2000
        // eth in pool = 100
        // then for 1 dai we get 0.05 eth
        // for 1 eth we get 20 dai

        price = (_reserveOut.mul(10 ** _reserveInDecimals)).div(_reserveIn);

        // output price is in decimals of thier native decimal values
        // if IN = USDC, OUT = WETH
        // then for given X * 10**6 USDC gives price in tersm of Y * 10** 18 WETH
    }

    function getPriceRange(uint256 before_Price, uint256 _fee, uint256 _tick)
        public
        pure
        returns (uint256 low, uint256 high)
    {
        // more fee => more swap range
        // more tick(stable) => more swap range
        // tick has more power to manipulate
        uint256 fee_log_square = SafeMath.log2(_fee) * SafeMath.log2(_fee);
        uint256 avg_2_root = SafeMath.sqrt(2 * (fee_log_square + _tick));
        uint256 range = (before_Price * avg_2_root) / 100;

        if (range >= before_Price) {
            low = 1;
            high = before_Price + range;
        } else {
            low = before_Price - range;
            high = before_Price + range;
        }
    }

    function getAmountFee(uint256 _amountIn, uint256 _fee) public pure returns (uint256 amountIn) {
        amountIn = (_amountIn.mul(_fee)).div(1000000);
    }
}
