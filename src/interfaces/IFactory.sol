// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IFactory {
    event PairCreated(
        address indexed token0, address indexed token1, address indexed pair, uint256 fee, uint256 poolCount
    );

    function owner() external view returns (address);
    function MAX_POOL_FEE() external view returns (uint256);
    function MIN_POOL_FEE() external view returns (uint256);
    function MAX_TICK() external view returns (uint256);
    function s_getPair(address _token0, address _token1, uint256 _fee) external view returns (address);
    function s_getTick(address _token0, address _token1) external view returns (uint256);
    function s_allPools(uint256 _index) external view returns (address);
    function allPoolsLength() external view returns (uint256);
    function getAllPoolsAddress() external view returns (address[] memory);

    function createPool(address _tokenA, address _tokenB, uint256 _fee) external returns (address);
    function setTicks(address[] memory _tokenA, address[] memory _tokenB, uint256[] memory _tick) external;
    function transferOwnership(address newOwner) external;
}
