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

    event AddLiquidity(address indexed from, address indexed to, uint256 amountA, uint256 amountB, uint256 liquidity);
    event RemoveLiquidity(
        address indexed from, address indexed to, uint256 liquidity, uint256 amountA, uint256 amountB
    );
    event Swap(address indexed from, address indexed to, uint256 amountIn, uint256 amountOut, uint256 amountInFee);

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
    function _addLiquidity(
        uint256 _amountADesired,
        uint256 _amountBDesired,
        uint256 _amountAMin,
        uint256 _amountBMin,
        uint256 _reserveA,
        uint256 _reserveB
    ) public pure returns (uint256 amountA, uint256 amountB) {
        // at initially liquidity we accept all the tokens
        if (_reserveA == 0 && _reserveB == 0) {
            (amountA, amountB) = (_amountADesired, _amountBDesired);
        } else {
            uint256 m_amountBOptimal = PoolLibrary.quote(_amountADesired, _reserveA, _reserveB);
            if (m_amountBOptimal <= _amountBDesired) {
                require(m_amountBOptimal >= _amountBMin, "POOL : Optimal amount-B exceed");
                (amountA, amountB) = (_amountADesired, m_amountBOptimal);
            } else {
                uint256 m_amountAOptimal = PoolLibrary.quote(_amountBDesired, _reserveB, _reserveA);
                require(m_amountAOptimal <= _amountADesired, "POOL : Insufficient liquidity added");
                require(m_amountAOptimal >= _amountAMin, "POOL : Optimal amount-A exceed");
                (amountA, amountB) = (m_amountAOptimal, _amountBDesired);
            }
        }
    }

    function _mintLiquidity(uint256 _amountA, uint256 _amountB, uint256 _reserveA, uint256 _reserveB)
        public
        view
        returns (uint256 liquidity)
    {
        uint256 m_totalSupply = totalSupply;

        if (m_totalSupply == 0) {
            liquidity = (SafeMath.sqrt(_amountA.mul(_amountB))).sub(MINIMUM_LIQUIDITY);
            // mimimum liquidity is locked perminently
        } else {
            liquidity =
                SafeMath.min((_amountA.mul(m_totalSupply)).div(_reserveA), (_amountB.mul(m_totalSupply)).div(_reserveB));
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
        uint256 m_reserveA = IERC20(TOKENA).balanceOf(address(this));
        uint256 m_reserveB = IERC20(TOKENB).balanceOf(address(this));
        address sender = msg.sender; // @gas-optimization

        (amountA, amountB) =
            _addLiquidity(_amountADesired, _amountBDesired, _amountAMin, _amountBMin, m_reserveA, m_reserveB);
        liquidity = _mintLiquidity(amountA, amountB, m_reserveA, m_reserveB);

        _safeTransferFrom(TOKENA, sender, address(this), amountA);
        _safeTransferFrom(TOKENB, sender, address(this), amountB);

        _mint(_to, liquidity);

        emit AddLiquidity(sender, _to, amountA, amountB, liquidity);
    }

    /* ------- REMOVE LIQUIDITY ------- */
    function _removeLiquidity(
        uint256 _liquidity,
        uint256 _amountAMin,
        uint256 _amountBMin,
        address _tokenA,
        address _tokenB,
        address _pool
    ) public view returns (uint256 amountA, uint256 amountB) {
        uint256 m_reserveA = IERC20(_tokenA).balanceOf(_pool);
        uint256 m_reserveB = IERC20(_tokenB).balanceOf(_pool);
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
    )
        external
        nonReentrant
        ensure(_deadline)
        zeroAddress(msg.sender)
        zeroAddress(_to)
        returns (uint256 amountA, uint256 amountB)
    {
        // checked at ERC20 contract   &    order of execution is importent
        (address m_tokenA, address m_tokenB, address m_pool) = (TOKENA, TOKENB, address(this)); // @gas-optimization

        (amountA, amountB) = _removeLiquidity(_liquidity, _amountAMin, _amountBMin, m_tokenA, m_tokenB, m_pool);

        _burn(msg.sender, _liquidity);
        _safeTransfer(m_tokenA, _to, amountA);
        _safeTransfer(m_tokenB, _to, amountB);

        // maintain minimum balance from hacking of pool
        require(IERC20(m_tokenA).balanceOf(m_pool) > 0, "POOL : Insufficient liquidity-A removed");
        require(IERC20(m_tokenB).balanceOf(m_pool) > 0, "POOL : Insufficient liquidity-B removed");

        emit RemoveLiquidity(msg.sender, _to, _liquidity, amountA, amountB);
    }

    /* ------- SWAP TOKENS ------- */
    function swapTokensExactInput(
        uint256 _amountIn,
        uint256 _amountOutMin,
        address _tokenIn,
        address _tokenOut,
        address _to,
        uint256 _deadline
    )
        external
        nonReentrant
        ensure(_deadline)
        zeroAddress(_to)
        zeroAddress(msg.sender)
        returns (uint256 amountOut, uint256 fee)
    {
        require(
            (_tokenIn == TOKENA && _tokenOut == TOKENB) || (_tokenIn == TOKENB && _tokenOut == TOKENA),
            "POOL : Invalid pool tokens"
        );

        uint256 m_reserveIn = IERC20(_tokenIn).balanceOf(address(this));
        uint256 m_reserveOut = IERC20(_tokenOut).balanceOf(address(this));
        uint256 m_reserveInDecimals = IERC20(_tokenIn).decimals();

        require(_amountIn > 0 && m_reserveIn > 0 && m_reserveOut > 0, "POOL : zero amount");

        uint256 before_Price = PoolLibrary.getCurrentPrice(m_reserveIn, m_reserveOut, m_reserveInDecimals);
        (uint256 low_price, uint256 high_price) = PoolLibrary.getPriceRange(before_Price, FEE, TICK);
        fee = PoolLibrary.getAmountFee(_amountIn, FEE);

        amountOut = PoolLibrary.getAmountOut(_amountIn.sub(fee), m_reserveIn, m_reserveOut);

        require(amountOut >= _amountOutMin, "POOL : Insufficient amount out");

        _safeTransferFrom(_tokenIn, msg.sender, address(this), _amountIn);
        _safeTransfer(_tokenOut, _to, amountOut);

        uint256 m_reserveIn_ = IERC20(_tokenIn).balanceOf(address(this));
        uint256 m_reserveOut_ = IERC20(_tokenOut).balanceOf(address(this));

        uint256 after_price = PoolLibrary.getCurrentPrice(m_reserveIn_, m_reserveOut_, m_reserveInDecimals);
        require(after_price >= low_price && after_price <= high_price, "POOL : Out of range swap");

        emit Swap(msg.sender, _to, _amountIn, amountOut, fee);
    }
    // stable pool is dangerous it does not depend on reserve, it always swap for stable values

    function swapTokensExactOutput(
        uint256 _amountOut,
        uint256 _amountInMax,
        address _tokenIn,
        address _tokenOut,
        address _to,
        uint256 _deadline
    )
        external
        nonReentrant
        ensure(_deadline)
        zeroAddress(_to)
        zeroAddress(msg.sender)
        returns (uint256 amountIn, uint256 fee)
    {
        require(
            (_tokenIn == TOKENA && _tokenOut == TOKENB) || (_tokenIn == TOKENB && _tokenOut == TOKENA),
            "POOL : Invalid tokens"
        );
        // amountIn checks at pool library
        uint256 m_reserveIn = IERC20(_tokenIn).balanceOf(address(this));
        uint256 m_reserveOut = IERC20(_tokenOut).balanceOf(address(this));
        uint256 m_reserveInDecimals = IERC20(_tokenIn).decimals();

        require(_amountOut > 0 && m_reserveIn > 0 && m_reserveOut > 0, "POOL : zero amount");

        uint256 before_Price = PoolLibrary.getCurrentPrice(m_reserveIn, m_reserveOut, m_reserveInDecimals);
        (uint256 low_price, uint256 high_price) = PoolLibrary.getPriceRange(before_Price, FEE, TICK);

        amountIn = PoolLibrary.getAmountIn(_amountOut, m_reserveIn, m_reserveOut);

        fee = PoolLibrary.getAmountFee(amountIn, FEE);
        amountIn = amountIn.add(fee);

        require(amountIn <= _amountInMax, "POOL : Excess amount in");

        _safeTransferFrom(_tokenIn, msg.sender, address(this), amountIn);
        _safeTransfer(_tokenOut, _to, _amountOut);

        uint256 m_reserveIn_ = IERC20(_tokenIn).balanceOf(address(this));
        uint256 m_reserveOut_ = IERC20(_tokenOut).balanceOf(address(this));

        uint256 after_price = PoolLibrary.getCurrentPrice(m_reserveIn_, m_reserveOut_, m_reserveInDecimals);
        require(after_price >= low_price && after_price <= high_price, "POOL : Out of range swap");

        emit Swap(msg.sender, _to, amountIn, _amountOut, fee);
    }

    // this function is called when any liquidity issues came
    function mintLiquidity(address _to, uint256 _liquidity) external {
        require(msg.sender == IFactory(FACTORY).owner(), "POOL : Invalid factory owner");
        _mint(_to, _liquidity);
    }
}
