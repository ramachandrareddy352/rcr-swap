// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "forge-std/Vm.sol";

import {Factory} from "../../src/Factory.sol";
import {Pool} from "../../src/Pool.sol";
import {ERC20} from "../helper/ERC20.sol";

import {CommonBase} from "forge-std/Base.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";

contract Handler is CommonBase, StdCheats, StdUtils {
    // apply all bounding functions and test them
    Factory internal factory;
    Pool[] internal pools;

    constructor(Factory _factory, Pool[] memory _pools) {
        factory = _factory;
        for(uint i=0; i<_pools.length; i++) {
            pools.push(_pools[i]);
        }
    }

    function addLiquidity(
        uint256 _index,
        uint256 _amountADesired,
        uint256 _amountBDesired,
        uint256 _amountAMin,
        uint256 _amountBMin,
        address _to,
        uint256 _deadline
    ) public {
        vm.assume(_to != address(0));
        _index = bound(_index, 0, pools.length - 1);
        pools[_index].addLiquidity(
            _amountADesired,
            _amountBDesired,
            _amountAMin,
            _amountBMin,
            _to,
            _deadline
        );
    }

    function removeLiquidity(
        uint256 _index,
        uint256 _liquidity,
        uint256 _amountAMin,
        uint256 _amountBMin,
        address _to,
        uint256 _deadline
    ) public {
        _index = bound(_index, 0, pools.length - 1);
        pools[_index].removeLiquidity(
            _liquidity,
            _amountAMin,
            _amountBMin,
            _to,
            _deadline
        );
    }

    function swapTokensExactInput(
        uint256 _index,
        uint256 _amountIn,
        uint256 _amountOutMin,
        address _tokenIn,
        address _tokenOut,
        address _to,
        uint256 _deadline
    ) public {
        _index = bound(_index, 0, pools.length - 1);
        pools[_index].swapTokensExactInput(
            _amountIn,
            _amountOutMin,
            _tokenIn,
            _tokenOut,
            _to,
            _deadline
        );
    }

    function swapTokensExactOutput(
        uint256 _index,
        uint256 _amountOut,
        uint256 _amountInMax,
        address _tokenIn,
        address _tokenOut,
        address _to,
        uint256 _deadline
    ) public {
        _index = bound(_index, 0, pools.length - 1);
        pools[_index].swapTokensExactOutput(
            _amountOut,
            _amountInMax,
            _tokenIn,
            _tokenOut,
            _to,
            _deadline
        );
    }

    // function transfer(address to, uint256 value) public {

    // }

    // function approve(address spender, uint256 value) public {

    // }

    // function transferFrom(address from, address to, uint256 value) public {

    // }
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
        
        ticks[0] = 50000;
        ticks[1] = 2000;
        ticks[2] = 3000;
        ticks[3] = 2500;

        factory = new Factory(pair1, pair2, ticks);

        pools.push(Pool(factory.createPool(address(dai), address(usdc), 3000)));   // 0.3% fee
        pools.push(Pool(factory.createPool(address(weth), address(wbtc), 1000)));      // 0.1% fee
        pools.push(Pool(factory.createPool(address(wbtc), address(usdc), 5000)));      // 0.5% fee
        pools.push(Pool(factory.createPool(address(dai), address(wbtc), 10000)));      // 1% fee
        pools.push(Pool(factory.createPool(address(unKnown), address(weth), 500)));      // 0.05% fee

        handler = new Handler(factory, pools);

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
