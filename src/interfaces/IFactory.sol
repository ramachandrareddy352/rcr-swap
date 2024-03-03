// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IFactory {
    event PairCreated(
        uint256 indexed poolCount,
        address token0,
        address token1,
        address indexed pair,
        uint256 fee,
        uint256 tick,
        address createdBy
    );

    struct _Pool {
        address tokenA;
        address tokenB;
        uint256 fee;
    }

    function MAX_POOL_FEE() external view returns (uint256);
    function MIN_POOL_FEE() external view returns (uint256);
    function MAX_TICK() external view returns (uint256);

    function getOwnerPools(address _owner) external view returns (uint256[] memory);
    function getPoolData(address _pool) external view returns (_Pool memory);
    function getPool(uint256 _id) external view returns (_Pool memory);
    function getTick(address _token0, address _token1) external view returns (uint256);
    function getPair(address _token0, address _token1, uint256 _fee) external view returns (address);
    function s_poolCount() external view returns (uint256);
    function owner() external view returns (address);
    function getAllPoolsAddress() external view returns (address[] memory);

    function createPool(address _tokenA, address _tokenB, uint256 _fee) external returns (address);
    function setTicks(address[] memory _tokenA, address[] memory _tokenB, uint256[] memory _tick) external;
    function transferOwnership(address newOwner) external;
}
