// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "./interfaces/IERC20.sol";
import {IFactory} from "./interfaces/IFactory.sol";
import {SafeMath} from "./libraries/SafeMath.sol";
import {LP_ERC20} from "./LP_ERC20.sol";
import {ReentrancyGuard} from "./utils/ReentrancyGuard.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {PoolLibrary} from "./PoolLibrary.sol";
import {SafeCast} from "./libraries/SafeCast.sol";

/**
 *  All the traded data is stored at ofline
 */
contract Pool is LP_ERC20, ReentrancyGuard, PoolLibrary {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    event AddLiquidity(uint256 amountA, uint256 amountB, uint256 liquidity);
    event RemoveLiquidity(uint256 liquidity, uint256 amountA, uint256 amountB);
    event Swap(uint256 amountIn, uint256 amountOut, uint256 amountInFee);

    address public immutable FACTORY;
    address public immutable TOKENA;
    address public immutable TOKENB;
    uint256 public immutable FEE;
    uint256 public immutable TICK;

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "POOL : deadline expired");
        _;
    }

    modifier zeroAddress(address _account) {
        require(_account != address(0), "POOL : Invaldi zero address");
        _;
    }

    constructor(address _factory, address _tokenA, address _tokenB, uint256 _fee, uint256 _tick) {
        FACTORY = _factory;
        TOKENA = _tokenA;
        TOKENB = _tokenB;
        FEE = _fee;
        TICK = _tick;
    }

    /* ------- ADD LIQUIDITY ------- */
    function _addLiquidity(uint256 _amountADesired, uint256 _amountBDesired, uint256 _amountAMin, uint256 _amountBMin)
        public
        view
        returns (uint256 amountA, uint256 amountB)
    {
        uint256 m_reserveA = IERC20(TOKENA).balanceOf(address(this));
        uint256 m_reserveB = IERC20(TOKENB).balanceOf(address(this));

        // initially liquidity we accept all the tokens
        if (m_reserveA == 0 && m_reserveB == 0) {
            (amountA, amountB) = (_amountADesired, _amountBDesired);
        } else {
            uint256 m_amountBOptimal = quote(_amountADesired, m_reserveA, m_reserveB);
            if (m_amountBOptimal <= _amountBDesired) {
                require(m_amountBOptimal >= _amountBMin, "POOL : Insufficient minimum token-B amount");
                (amountA, amountB) = (_amountADesired, m_amountBOptimal);
            } else {
                uint256 m_amountAOptimal = quote(_amountBDesired, m_reserveB, m_reserveA);
                require(m_amountAOptimal <= _amountADesired, "POOL : Insufficient token-A desired");
                require(m_amountAOptimal >= _amountAMin, "POOL : Insufficient minimum token-A amount");
                (amountA, amountB) = (m_amountAOptimal, _amountBDesired);
            }
        }
    }

    function _mintLiquidity(uint256 _amountA, uint256 _amountB) public view returns (uint256 liquidity) {
        uint256 m_totalSupply = totalSupply;
        uint256 m_reserveA = IERC20(TOKENA).balanceOf(address(this));
        uint256 m_reserveB = IERC20(TOKENB).balanceOf(address(this));

        if (m_totalSupply == 0) {
            liquidity = SafeMath.sqrt(_amountA.mul(_amountB));
        } else {
            liquidity = SafeMath.min(
                (_amountA.mul(m_totalSupply)).div(m_reserveA), (_amountB.mul(m_totalSupply)).div(m_reserveB)
            );
        }
        require(liquidity > 0, "POOL : Invalid mint liquidity");
    }

    function addLiquidity(
        uint256 _amountADesired,
        uint256 _amountBDesired,
        uint256 _amountAMin,
        uint256 _amountBMin,
        address _to,
        uint256 _deadline
    )
        external
        nonReentrant
        ensure(_deadline)
        zeroAddress(_to)
        returns (uint256 amountA, uint256 amountB, uint256 liquidity)
    {
        // after and before adding liquidity the price of tokens not to be change.
        // order of execution is importent
        require(_amountADesired > 0 && _amountBDesired > 0, "POOL : Zero amount desired");

        (amountA, amountB) = _addLiquidity(_amountADesired, _amountBDesired, _amountAMin, _amountBMin);
        liquidity = _mintLiquidity(amountA, amountB);

        // SafeERC20.safeTransferFrom(IERC20(TOKENA), msg.sender, address(this), amountA);
        // SafeERC20.safeTransferFrom(IERC20(TOKENB), msg.sender, address(this), amountB);

        _mint(_to, liquidity);

        emit AddLiquidity(amountA, amountB, liquidity);
    }

    /* ------- REMOVE LIQUIDITY ------- */

    function _removeLiquidity(uint256 _liquidity, uint256 _amountAMin, uint256 _amountBMin)
        public
        view
        returns (uint256 amountA, uint256 amountB)
    {
        uint256 m_reserveA = IERC20(TOKENA).balanceOf(address(this));
        uint256 m_reserveB = IERC20(TOKENB).balanceOf(address(this));
        uint256 m_totalSupply = totalSupply;

        amountA = (m_reserveA.mul(_liquidity)).div(m_totalSupply);
        amountB = (m_reserveB.mul(_liquidity)).div(m_totalSupply);
        require(amountA > 0 && amountA >= _amountAMin, "POOL : Insufficient token-A");
        require(amountB > 0 && amountB >= _amountBMin, "POOL : Insufficient token-B");
    }

    function removeLiquidity(
        uint256 _liquidity,
        uint256 _amountAMin,
        uint256 _amountBMin,
        address _to,
        uint256 _deadline
    ) external nonReentrant ensure(_deadline) zeroAddress(_to) returns (uint256 amountA, uint256 amountB) {
        // require(_liquidity <= balanceOf[msg.sender], "POOL : Insufficient liquidity");
        // checked at ERC20 contract   &    order of execution is importent
        (amountA, amountB) = _removeLiquidity(_liquidity, _amountAMin, _amountBMin);
        _burn(msg.sender, _liquidity);

        // SafeERC20.safeTransfer(IERC20(TOKENA), _to, amountA);
        // SafeERC20.safeTransfer(IERC20(TOKENB), _to, amountB);

        // after creating pool and adding liquidity, we have to maintain the greater than 0 reservers of both
        // tokens to continue the pool
        require(IERC20(TOKENA).balanceOf(address(this)) > 0, "POOL : Insufficient liquidity removed");
        require(IERC20(TOKENB).balanceOf(address(this)) > 0, "POOL : Insufficient liquidity removed");

        emit RemoveLiquidity(_liquidity, amountA, amountB);
    }

    /* ------- SWAP TOKENS ------- */
    // check the decimal issue

    /**
     * we calculate the liquidity before swap and find the range of liquidity, between this range only
     * the swap has to done.
     * The range is finded using before swaping of liquidity, reservers, fee, tick.
     */
    function swapTokensExactInput(
        uint256 _amountIn,
        uint256 _amountOutMin,
        address _tokenIn,
        address _tokenOut,
        address _to,
        uint256 _deadline
    ) external nonReentrant ensure(_deadline) zeroAddress(_to) zeroAddress(msg.sender) returns (uint256 amountOut) {
        require(
            (_tokenIn == TOKENA && _tokenOut == TOKENB) || (_tokenIn == TOKENB && _tokenOut == TOKENA),
            "POOL : Invalid tokens"
        );
        // amountIn checks at pool library
        uint256 m_reserveIn = IERC20(_tokenIn).balanceOf(address(this));
        uint256 m_reserveOut = IERC20(_tokenOut).balanceOf(address(this));

        uint256 m_amountInFee = getAmountFee(_amountIn, FEE);
        uint256 m_amountInWithOutFee = _amountIn.sub(m_amountInFee);
        int256 m_amountOut = getAmountOut(
            SafeCast.toInt256(m_amountInWithOutFee),
            SafeCast.toInt256(m_reserveIn),
            SafeCast.toInt256(m_reserveOut),
            SafeCast.toInt256(m_reserveIn.add(m_reserveOut)),
            SafeCast.toInt256(TICK)
        );
        amountOut = SafeCast.toUint256(m_amountOut);
        require(amountOut >= _amountOutMin, "POOL : Insufficient amount out");

        uint256 m_beforeLiquidity = m_reserveIn.mul(m_reserveOut);
        (uint256 m_lowLiquidity, uint256 m_highLiquidity) =
            getLiquidityRange(m_reserveIn, m_reserveOut, FEE, TICK, m_beforeLiquidity);

        // SafeERC20.safeTransferFrom(IERC20(_tokenIn), msg.sender, address(this), _amountIn);
        // SafeERC20.safeTransfer(IERC20(_tokenOut), _to, amountOut);

        uint256 m_afterLiquidity = m_reserveIn.mul(m_reserveOut);
        require(
            m_afterLiquidity > 0 && m_afterLiquidity >= m_lowLiquidity && m_afterLiquidity <= m_highLiquidity,
            "POOL : out of range swap"
        );

        emit Swap(_amountIn, amountOut, m_amountInFee);
    }

    function swapTokensExactOutput(
        uint256 _amountOut,
        uint256 _amountInMax,
        address _tokenIn,
        address _tokenOut,
        address _to,
        uint256 _deadline
    ) external nonReentrant ensure(_deadline) zeroAddress(_to) zeroAddress(msg.sender) returns (uint256 amountIn) {
        require(
            (_tokenIn == TOKENA && _tokenOut == TOKENB) || (_tokenIn == TOKENB && _tokenOut == TOKENA),
            "POOL : Invalid tokens"
        );
        // amountIn checks at pool library
        uint256 m_reserveIn = IERC20(_tokenIn).balanceOf(address(this));
        uint256 m_reserveOut = IERC20(_tokenOut).balanceOf(address(this));

        int256 m_amountIn = getAmountIn(
            SafeCast.toInt256(_amountOut),
            SafeCast.toInt256(m_reserveIn),
            SafeCast.toInt256(m_reserveOut),
            SafeCast.toInt256(m_reserveIn.add(m_reserveOut)),
            SafeCast.toInt256(TICK)
        );
        amountIn = SafeCast.toUint256(m_amountIn);

        uint256 m_amountInFee = getAmountFee(amountIn, FEE);
        amountIn = amountIn.add(m_amountInFee);

        require(amountIn <= _amountInMax, "POOL : Excess amount in");

        uint256 m_beforeLiquidity = m_reserveIn.mul(m_reserveOut);
        (uint256 m_lowLiquidity, uint256 m_highLiquidity) =
            getLiquidityRange(m_reserveIn, m_reserveOut, FEE, TICK, m_beforeLiquidity);

        // SafeERC20.safeTransferFrom(IERC20(_tokenIn), msg.sender, address(this), _amountIn);
        // SafeERC20.safeTransfer(IERC20(_tokenOut), _to, _amountOut);

        uint256 m_afterLiquidity = m_reserveIn.mul(m_reserveOut);
        require(
            m_afterLiquidity > 0 && m_afterLiquidity >= m_lowLiquidity && m_afterLiquidity <= m_highLiquidity,
            "POOL : Out of range swap"
        );

        emit Swap(amountIn, _amountOut, m_amountInFee);
    }

    // this function is called when any liquidity issues came
    function mintLiquidity(address _to, uint256 _liquidity) external {
        require(msg.sender == IFactory(FACTORY).owner(), "POOL : Invalid factory owner");
        _mint(_to, _liquidity);
    }
}
