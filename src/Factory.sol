// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Pool} from "./Pool.sol";
import {SafeMath} from "./libraries/SafeMath.sol";
import {Ownable} from "./utils/Ownable.sol";

contract Factory is Ownable {
    using SafeMath for uint256;

    event PairCreated(
        uint256 indexed poolCount,
        address token0,
        address token1,
        address indexed pair,
        uint256 fee,
        uint256 tick,
        address createdBy
    );

    // dynamic tick spacing is allowed
    // for same pair of tokens we can create 198 different pools
    uint256 public constant MAX_POOL_FEE = 10000; // 1%
    uint256 public constant MIN_POOL_FEE = 100; // 0.01%
    uint256 public constant MAX_TICK = 100;

    struct _Pool {
        address tokenA;
        address tokenB;
        uint256 fee;
    }

    mapping(address token0 => mapping(address token1 => mapping(uint256 fee => address pool))) private s_getPair;
    mapping(address token0 => mapping(address token1 => uint256 tick)) private s_getTick;
    mapping(uint256 id => _Pool) private s_Pools;
    mapping(address pool => _Pool) private s_getPoolData;
    mapping(address owner => uint256[] poolNums) private s_ownerPools;

    uint256 public s_poolCount; // pool count starts from 1

    address[] public s_allPools;

    constructor(address[] memory _tokenA, address[] memory _tokenB, uint256[] memory _tick) Ownable(msg.sender) {
        require(_tokenA.length == _tokenB.length && _tokenA.length == _tick.length, "Factory : Invalid length");
        for (uint256 i = 0; i < _tokenA.length;) {
            _setTick(_tokenA[i], _tokenB[i], _tick[i]);
            unchecked {
                i = i.add(1);
            }
        }
    }

    function createPool(address _tokenA, address _tokenB, uint256 _fee) external returns (address m_pair) {
        // factory allows 0.01% to 1% of _fee amount for a pool to create
        require(_tokenA != address(0) && _tokenB != address(0), "Factory : Invalid zero address");
        require(_tokenA != _tokenB, "Factory : Identical tokens");
        // its better to use fee%50 == 0 due to rounding of data
        // less the fee can help to maintain the price by swaping in less range of tokens
        require(_fee >= MIN_POOL_FEE && _fee <= MAX_POOL_FEE && _fee.mod(50) == 0, "Factory : Invalid fee");
        require(s_getPair[_tokenA][_tokenB][_fee] == address(0), "Factory : Pool alreday exist");

        (address m_token0, address m_token1) = _tokenA < _tokenB ? (_tokenA, _tokenB) : (_tokenB, _tokenA);

        s_poolCount++;
        uint256 m_tick = s_getTick[m_token0][m_token1]; // gas optimization
        uint256 m_poolCount = s_poolCount;
        address m_owner = msg.sender;

        m_pair = address(new Pool(address(this), m_token0, m_token1, _fee, m_tick));

        s_getPair[m_token0][m_token1][_fee] = m_pair;
        s_getPair[m_token1][m_token0][_fee] = m_pair;
        s_allPools.push(m_pair);

        s_Pools[m_poolCount] = _Pool(m_token0, m_token1, _fee);
        s_getPoolData[m_pair] = _Pool(m_token0, m_token1, _fee);
        s_ownerPools[m_owner].push(m_poolCount);

        emit PairCreated(m_poolCount, m_token0, m_token1, m_pair, _fee, m_tick, m_owner);
    }

    /**
     * for well known some pools owner add tick values
     * if the two tokens are stabel coins then the pool act as constant sum
     * if one token is stabel and other is not stable(known token) the pool act in both nature of sum anproduct
     * if two tokens are unknown or not stable the pool act as constant product(x*y)
     * more the tick value means more the pool act as constant sum(x+y)
     */
    function setTicks(address[] memory _tokenA, address[] memory _tokenB, uint256[] memory _tick) external onlyOwner {
        require(_tokenA.length == _tokenB.length && _tokenA.length == _tick.length, "Factory : Invalid length");
        for (uint256 i = 0; i < _tokenA.length;) {
            _setTick(_tokenA[i], _tokenB[i], _tick[i]);
            unchecked {
                i = i.add(1);
            }
        }
    }

    function _setTick(address _tokenA, address _tokenB, uint256 _tick) private {
        // tick should be in range of 0-100(better positions at x+y = 1 Million * 10**18)
        // (1-3) best for one stabel and non-stabel
        // (4-20) for both stable
        require(_tokenA != address(0) && _tokenA != _tokenB, "Factory : Invalid zero address");
        require(_tick <= MAX_TICK, "Factory : High tick position");
        s_getTick[_tokenA][_tokenB] = _tick;
        s_getTick[_tokenB][_tokenA] = _tick;
    }

    function getOwnerPools(address _owner) external view returns (uint256[] memory) {
        return s_ownerPools[_owner];
    }

    function getPoolData(address _pool) external view returns (_Pool memory) {
        return s_getPoolData[_pool];
    }

    function getPool(uint256 _id) external view returns (_Pool memory) {
        return s_Pools[_id];
    }

    function getTick(address _token0, address _token1) external view returns (uint256) {
        return s_getTick[_token0][_token1];
    }

    function getPair(address _token0, address _token1, uint256 _fee) external view returns (address) {
        return s_getPair[_token0][_token1][_fee];
    }

    function getAllPoolsAddress() external view returns (address[] memory) {
        return s_allPools;
    }
}
