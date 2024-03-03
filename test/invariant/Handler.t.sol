// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "forge-std/Vm.sol";

import {Factory} from "../../src/Factory.sol";
import {Pool} from "../../src/Pool.sol";
import {ERC20} from "../helper/ERC20.sol";
import {PoolLibrary} from "../helper/PoolLibrary.sol";

import {CommonBase} from "forge-std/Base.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";

contract Handler is CommonBase, StdCheats, StdUtils {
    // apply all bounding functions and test them
    Factory internal factory;
    Pool[] internal pools;
    PoolLibrary poolLibrary;

    address[] internal traders = new address[](5);

    ERC20 dai;
    ERC20 usdc;
    ERC20 weth;
    ERC20 wbtc;
    ERC20 unKnown;

    address[] internal tokens = new address[](5);

    constructor(
        Factory _factory,
        Pool[] memory _pools,
        ERC20 _dai,
        ERC20 _usdc,
        ERC20 _weth,
        ERC20 _wbtc,
        ERC20 _unKnown
    ) {
        factory = _factory;
        poolLibrary = new PoolLibrary();

        for (uint256 i = 0; i < _pools.length; i++) {
            pools.push(_pools[i]);
        }
        dai = _dai;
        usdc = _usdc;
        weth = _weth;
        wbtc = _wbtc;
        unKnown = _unKnown;

        tokens.push(address(dai));
        tokens.push(address(usdc));
        tokens.push(address(weth));
        tokens.push(address(wbtc));
        tokens.push(address(unKnown));

        traders[0] = address(1);
        traders[1] = address(2);
        traders[2] = address(3);
        traders[3] = address(4);
        traders[4] = address(5);
    }

    function addLiquidity(
        uint256 _traderIndex,
        uint256 _poolIndex,
        uint256 _amountADesired,
        uint256 _amountBDesired,
        address _to
    ) public {
        // vm.assume(_traderIndex >=0 && _traderIndex < traders.length);
        // vm.assume(_poolIndex >=0 && _poolIndex < pools.length);

        // _traderIndex = bound(_traderIndex, 0, traders.length - 1);
        // _poolIndex = bound(_poolIndex, 0, pools.length - 1);

        _traderIndex = _traderIndex % traders.length;
        _poolIndex = _poolIndex % pools.length;
        _amountADesired = _amountADesired % 10**30 + 1;  // always be greater than zero
        _amountBDesired = _amountBDesired % 10**30 + 1;

        (address tokenA, address tokenB, ) = factory.getPoolData(address(pools[_poolIndex]));

        // sending that much of amount
        ERC20(tokenA).mint(traders[_traderIndex], _amountADesired + 1);
        ERC20(tokenB).mint(traders[_traderIndex], _amountBDesired + 1);

        vm.startPrank(traders[_traderIndex]);
        
        ERC20(tokenA).approve(address(pools[_poolIndex]), type(uint256).max);
        ERC20(tokenB).approve(address(pools[_poolIndex]), type(uint256).max);

        pools[_poolIndex].addLiquidity(_amountADesired, _amountBDesired, 0, 0, _to, block.timestamp + 1);

        vm.stopPrank();
    }

    function removeLiquidity(uint256 _traderIndex, uint256 _poolIndex, uint256 _liquidity, address _to)
        public
    {
        _traderIndex = _traderIndex % traders.length;
        _poolIndex = _poolIndex % pools.length;

        Pool pool = pools[_poolIndex];
        (address tokenA, address tokenB, ) = factory.getPoolData(address(pool));
        uint256 traderLiquidityBalance = pool.balanceOf(traders[_traderIndex]);
        
        vm.startPrank(traders[_traderIndex]);
        
        vm.assume(traderLiquidityBalance > 0);

        pools[_poolIndex].removeLiquidity(traderLiquidityBalance, 0, 0, _to, block.timestamp + 1);

        vm.stopPrank();
    }

    function swapTokensExactInput(
        uint256 _traderIndex,
        uint256 _poolIndex,
        uint256 _amountIn,
        address _to
    ) public {
        _traderIndex = _traderIndex % traders.length;
        _poolIndex = _poolIndex % pools.length;
        vm.assume(_amountIn > 0 && _amountIn < 1e24);

        Pool pool = pools[_poolIndex];
        address tokenIn = pool.TOKENA();
        address tokenOut = pool.TOKENB();

        vm.startPrank(traders[_traderIndex]);
        
        ERC20(tokenIn).mint(traders[_traderIndex], _amountIn);
        ERC20(tokenIn).approve(address(pool), type(uint).max);
        pool.swapTokensExactInput(_amountIn, 0, tokenIn, tokenOut, _to, block.timestamp + 1);

        vm.stopPrank();
    }

    function swapTokensExactOutput(
        uint256 _traderIndex,
        uint256 _poolIndex,
        uint256 _amountOut,
        address _to
    ) public {
        _traderIndex = _traderIndex % traders.length;
        _poolIndex = _poolIndex % pools.length;
        vm.assume(_amountOut > 0 && _amountOut < 1e24);

        Pool pool = pools[_poolIndex];
        address tokenIn = pool.TOKENA();
        address tokenOut = pool.TOKENB();

        vm.startPrank(traders[_traderIndex]);

        vm.assume(_amountOut < ERC20(tokenOut).balanceOf(address(pool)));

        uint amountIn = poolLibrary.getAmountIn(
            _amountOut, 
            ERC20(tokenIn).balanceOf(address(pool)), 
            ERC20(tokenOut).balanceOf(address(pool))
        );
        
        ERC20(tokenIn).mint(traders[_traderIndex], amountIn + 100);
        ERC20(tokenIn).approve(address(pool), type(uint).max);

        pool.swapTokensExactOutput(_amountOut, type(uint).max, tokenIn, tokenOut, _to, block.timestamp + 1);

        vm.stopPrank();
    }
}

contract Pool_Handler_Test is Test {
    Factory internal factory;
    Pool[] internal pools;

    ERC20 dai;
    ERC20 usdc;
    ERC20 weth;
    ERC20 wbtc;
    ERC20 unKnown;

    Handler handler;

    function setUp() public {
        dai = new ERC20("token-A", "DAI", 18);
        usdc = new ERC20("token-B", "USDC", 6);
        weth = new ERC20("token-C", "WETH", 18);
        wbtc = new ERC20("token-D", "WBTC", 18);
        unKnown = new ERC20("token-E", "UNKNOWN", 18);

        address[] memory pair1 = new address[](4);
        address[] memory pair2 = new address[](4);
        uint256[] memory ticks = new uint256[](4);

        pair1[0] = address(dai);
        pair1[1] = address(weth);
        pair1[2] = address(wbtc);
        pair1[3] = address(dai);

        pair2[0] = address(usdc);
        pair2[1] = address(wbtc);
        pair2[2] = address(usdc);
        pair2[3] = address(wbtc);

        ticks[0] = 5000;
        ticks[1] = 2000;
        ticks[2] = 3000;
        ticks[3] = 2500;

        factory = new Factory(pair1, pair2, ticks);

        pools.push(Pool(factory.createPool(address(dai), address(usdc), 3000))); // 0.3% fee
        pools.push(Pool(factory.createPool(address(weth), address(wbtc), 1000))); // 0.1% fee
        pools.push(Pool(factory.createPool(address(wbtc), address(usdc), 5000))); // 0.5% fee
        pools.push(Pool(factory.createPool(address(dai), address(wbtc), 10000))); // 1% fee
        pools.push(Pool(factory.createPool(address(unKnown), address(weth), 500))); // 0.05% fee

        handler = new Handler(factory, pools, dai, usdc, weth, wbtc, unKnown);

        targetContract(address(handler));

        // bytes4[] memory selectors = new bytes4[](5);
        // selectors[0] = Handler.addLiquidity.selector;
        // selectors[1] = Handler.removeLiquidity.selector;
        // selectors[2] = Handler.swapTokensExactInput.selector;
        // selectors[3] = Handler.swapTokensExactOutput.selector;

        // targetSelector(
        //     FuzzSelector({addr: address(handler), selectors: selectors})
        // );
    }

    function invariant_testName1() public {
        // console.log("handler num calls", handler.numCalls());
    }

    // function invariant_testName2() public {

    // }
}
