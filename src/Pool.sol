// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "./interfaces/IERC20.sol";
import {IFactory} from "./interfaces/IFactory.sol";
import {SafeMath} from "./libraries/SafeMath.sol";
import {LP_ERC20} from "./LP_ERC20.sol";
import {ReentrancyGuard} from "./utils/ReentrancyGuard.sol";
import {PoolLibrary} from "./libraries/PoolLibrary.sol";
import {SafeCast} from "./libraries/SafeCast.sol";

/**
 * All the traded data is stored at ofline
 * Once pool created with tokens , we have to maintain greater than zero balance of tokens for every time
 */
contract Pool is LP_ERC20, ReentrancyGuard {
    using SafeMath for uint256;

    event AddLiquidity(uint256 amountA, uint256 amountB, uint256 liquidity);
    event RemoveLiquidity(uint256 liquidity, uint256 amountA, uint256 amountB);
    event Swap(uint256 amountIn, uint256 amountOut, uint256 amountInFee);

    uint256 public constant MINIMUM_LIQUIDITY = 1000;
    bytes4 private constant TRANSFER_SELECTOR = bytes4(keccak256(bytes("transfer(address,uint256)")));
    bytes4 private constant TRANSFER_FROM_SELECTOR = bytes4(keccak256(bytes("transferFrom(address,address,uint256)")));

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

    function _safeTransfer(address token, address to, uint256 value) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(TRANSFER_SELECTOR, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "POOL : Transfer failed");
    }

    function _safeTransferFrom(address token, address from, address to, uint256 value) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(TRANSFER_FROM_SELECTOR, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "POOL : Transfer from failed");
    }

    /* ------- ADD LIQUIDITY ------- */
    function _addLiquidity(uint256 _amountADesired, uint256 _amountBDesired, uint256 _amountAMin, uint256 _amountBMin)
        public
        view
        returns (uint256 amountA, uint256 amountB)
    {
        uint256 m_reserveA = getReserveA(); // 18
        uint256 m_reserveB = getReserveB(); // 6

        // initially liquidity we accept all the tokens
        if (m_reserveA == 0 && m_reserveB == 0) {
            (amountA, amountB) = (_amountADesired, _amountBDesired);
        } else {
            uint256 m_amountBOptimal = PoolLibrary.quote(_amountADesired, m_reserveA, m_reserveB);
            if (m_amountBOptimal <= _amountBDesired) {
                require(m_amountBOptimal >= _amountBMin, "POOL : Insufficient minimum token-B amount");
                (amountA, amountB) = (_amountADesired, m_amountBOptimal);
            } else {
                uint256 m_amountAOptimal = PoolLibrary.quote(_amountBDesired, m_reserveB, m_reserveA);
                require(m_amountAOptimal <= _amountADesired, "POOL : Insufficient token-A desired");
                require(m_amountAOptimal >= _amountAMin, "POOL : Insufficient minimum token-A amount");
                (amountA, amountB) = (m_amountAOptimal, _amountBDesired);
            }
        }
    }

    function _mintLiquidity(uint256 _amountA, uint256 _amountB) public view returns (uint256 liquidity) {
        uint256 m_totalSupply = totalSupply;
        uint256 m_reserveA = getReserveA();
        uint256 m_reserveB = getReserveB();

        if (m_totalSupply == 0) {
            liquidity = (SafeMath.sqrt(_amountA.mul(_amountB))).sub(MINIMUM_LIQUIDITY);
            // mimimum liquidity is locked
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
        zeroAddress(msg.sender)
        returns (uint256 amountA, uint256 amountB, uint256 liquidity)
    {
        // check the given are correct token address
        // after and before adding liquidity the price of tokens not to be change.
        // order of execution is importent
        require(_amountADesired > 0 && _amountBDesired > 0, "POOL : Zero amount desired");

        (amountA, amountB) = _addLiquidity(_amountADesired, _amountBDesired, _amountAMin, _amountBMin);
        liquidity = _mintLiquidity(amountA, amountB);

        _safeTransferFrom(TOKENA, msg.sender, address(this), amountA);
        _safeTransferFrom(TOKENB, msg.sender, address(this), amountB);

        _mint(_to, liquidity);

        emit AddLiquidity(amountA, amountB, liquidity);
    }

    /* ------- REMOVE LIQUIDITY ------- */

    function _removeLiquidity(uint256 _liquidity, uint256 _amountAMin, uint256 _amountBMin)
        public
        view
        returns (uint256 amountA, uint256 amountB)
    {
        uint256 m_reserveA = getReserveA();
        uint256 m_reserveB = getReserveB();
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

        _safeTransfer(TOKENA, _to, amountA);
        _safeTransfer(TOKENB, _to, amountB);

        // after creating pool and adding liquidity, we have to maintain the greater than 0 reservers of both
        // tokens to continue the pool
        require(getReserveA() > 0, "POOL : Insufficient liquidity removed");
        require(getReserveB() > 0, "POOL : Insufficient liquidity removed");

        emit RemoveLiquidity(_liquidity, amountA, amountB);
    }

    /* ------- SWAP TOKENS ------- */
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

        uint256 before_Price = PoolLibrary.getCurrentPrice(_tokenIn, _tokenOut, address(this));
        (uint256 low_price, uint256 high_price) = PoolLibrary.getPriceRange(before_Price, FEE, TICK);

        uint256 m_amountInFee = PoolLibrary.getAmountFee(_amountIn, FEE);
        uint256 m_amountInWithOutFee = _amountIn.sub(m_amountInFee);

        m_amountInWithOutFee = PoolLibrary.convertTo18Decimals(_tokenIn, m_amountInWithOutFee);
        m_reserveIn = PoolLibrary.convertTo18Decimals(_tokenIn, m_reserveIn);
        m_reserveOut = PoolLibrary.convertTo18Decimals(_tokenOut, m_reserveOut);

        int256 m_amountOut = PoolLibrary.getAmountOut(
            SafeCast.toInt256(m_amountInWithOutFee),
            SafeCast.toInt256(m_reserveIn),
            SafeCast.toInt256(m_reserveOut),
            SafeCast.toInt256(TICK)
        );

        amountOut = SafeCast.toUint256(m_amountOut);
        amountOut = PoolLibrary.convertToNative(_tokenOut, amountOut);
        require(amountOut >= _amountOutMin, "POOL : Insufficient amount out");

        _safeTransferFrom(_tokenIn, msg.sender, address(this), _amountIn);
        _safeTransfer(_tokenOut, _to, amountOut);

        uint256 after_price = PoolLibrary.getCurrentPrice(_tokenIn, _tokenOut, address(this));
        require(after_price >= low_price && after_price <= high_price, "POOL : Out of range swap");

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

        uint256 before_Price = PoolLibrary.getCurrentPrice(_tokenIn, _tokenOut, address(this));
        (uint256 low_price, uint256 high_price) = PoolLibrary.getPriceRange(before_Price, FEE, TICK);

        _amountOut = PoolLibrary.convertTo18Decimals(_tokenOut, _amountOut);
        m_reserveIn = PoolLibrary.convertTo18Decimals(_tokenIn, m_reserveIn);
        m_reserveOut = PoolLibrary.convertTo18Decimals(_tokenOut, m_reserveOut);

        int256 m_amountIn = PoolLibrary.getAmountIn(
            SafeCast.toInt256(_amountOut),
            SafeCast.toInt256(m_reserveIn),
            SafeCast.toInt256(m_reserveOut),
            SafeCast.toInt256(TICK)
        );

        amountIn = SafeCast.toUint256(m_amountIn);
        amountIn = PoolLibrary.convertToNative(_tokenIn, amountIn);

        uint256 m_amountInFee = PoolLibrary.getAmountFee(amountIn, FEE);
        amountIn = amountIn.add(m_amountInFee);

        require(amountIn <= _amountInMax, "POOL : Excess amount in");

        _safeTransferFrom(_tokenIn, msg.sender, address(this), amountIn);
        _safeTransfer(_tokenOut, _to, _amountOut);

        uint256 after_price = PoolLibrary.getCurrentPrice(_tokenIn, _tokenOut, address(this));
        require(after_price >= low_price && after_price <= high_price, "POOL : Out of range swap");

        emit Swap(amountIn, _amountOut, m_amountInFee);
    }

    // this function is called when any liquidity issues came
    function mintLiquidity(address _to, uint256 _liquidity) external {
        require(msg.sender == IFactory(FACTORY).owner(), "POOL : Invalid factory owner");
        _mint(_to, _liquidity);
    }

    function getReserveA() public view returns (uint256) {
        return IERC20(TOKENA).balanceOf(address(this));
    }

    function getReserveB() public view returns (uint256) {
        return IERC20(TOKENB).balanceOf(address(this));
    }
}
