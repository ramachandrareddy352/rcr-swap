// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IPool {
    event AddLiquidity(uint256 amountA, uint256 amountB, uint256 liquidity);
    event RemoveLiquidity(uint256 liquidity, uint256 amountA, uint256 amountB);
    event Swap(uint256 amountIn, uint256 amountOut, uint256 amountInFee);

    function FACTORY() external view returns (address);
    function TOKENA() external view returns (address);
    function TOKENB() external view returns (address);
    function TICK() external view returns (address);
    function FEE() external view returns (address);

    function _addLiquidity(uint256 _amountADesired, uint256 _amountBDesired, uint256 _amountAMin, uint256 _amountBMin)
        external
        view
        returns (uint256 amountA, uint256 amountB);

    function _mintLiquidity(uint256 _amountA, uint256 _amountB) external view returns (uint256 liquidity);

    function addLiquidity(
        uint256 _amountADesired,
        uint256 _amountBDesired,
        uint256 _amountAMin,
        uint256 _amountBMin,
        address _to,
        uint256 _deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);

    function _removeLiquidity(uint256 _liquidity, uint256 _amountAMin, uint256 _amountBMin)
        external
        view
        returns (uint256 amountA, uint256 amountB);

    function removeLiquidity(
        uint256 _liquidity,
        uint256 _amountAMin,
        uint256 _amountBMin,
        address _to,
        uint256 _deadline
    ) external returns (uint256 amountA, uint256 amountB);

    function swapTokensExactInput(
        uint256 _amountIn,
        uint256 _amountOutMin,
        address _tokenIn,
        address _tokenOut,
        address _to,
        uint256 _deadline
    ) external returns (uint256 amountOut);

    function swapTokensExactOutput(
        uint256 _amountOut,
        uint256 _amountInMax,
        address _tokenIn,
        address _tokenOut,
        address _to,
        uint256 _deadline
    ) external returns (uint256 amountIn);
}
