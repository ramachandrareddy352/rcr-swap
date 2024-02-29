// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "forge-std/Vm.sol";

import {ERC20} from "../helper/ERC20.sol";
import {IERC20} from "../helper/IERC20.sol";

import {Factory} from "../../src/Factory.sol";
import {Pool} from "../../src/Pool.sol";
import {SafeMath} from "../../src/libraries/SafeMath.sol";

contract StablePoolTest is Test {

    using SafeMath for uint256;

    ERC20 internal USDC;
    ERC20 internal DAI;

    Factory internal factory;
    Pool internal pool;

    address internal owner = address(1);

    function setUp() public {
        USDC = new ERC20("TOKEN-A", "USDC", 6);
        DAI = new ERC20("TOKEN-B", "DAI", 18);

        uint[] memory tick = new uint[](1);
        tick[0] = 100;
        address[] memory pair1 = new address[](1);
        pair1[0] = address(USDC);
        address[] memory pair2 = new address[](1);
        pair2[0] = address(DAI);
        
        vm.prank(owner);
        factory = new Factory(pair1, pair2 , tick);   // tick is set to 100
        
        // set fee as 0.3% 
        pool = Pool(factory.createPool(address(USDC), address(DAI), 3000));
    }

    function test_poolConstructor() external {
        assertEq(pool.FACTORY(), address(factory));
        assertEq(pool.TOKENA(), address(DAI));
        assertEq(pool.TOKENB(), address(USDC));
        assertEq(pool.FEE(), 3000);
        assertEq(pool.TICK(), 100);
    }

    function test_dataBeforeActions() external {
        assertEq(pool.balanceOf(address(pool)), 0);
        assertEq(pool.totalSupply(), 0);
        assertEq(pool.getReserveA(), 0);
        assertEq(pool.getReserveB(), 0);
    }

    function test_fails_InvalidLiquidityData() external {
        vm.expectRevert("POOL : Zero amount desired");
        pool.addLiquidity(0, 0, 0, 0, owner, block.timestamp+1);

        vm.expectRevert("POOL : deadline expired");
        pool.addLiquidity(0, 0, 0, 0, owner, block.timestamp-1);
        
        vm.startPrank(address(0));
        vm.expectRevert("POOL : Invaldi zero address");
        pool.addLiquidity(0, 0, 0, 0, owner, block.timestamp+1);
        vm.stopPrank();
    }

    function _mintTokens(address to, uint amount) private {
        DAI.mint(to, amount * 10**18);
        USDC.mint(to, amount * 10**6);
    }

    function test_addLiquidity() public {
        // initially we mint 1000 tokens each
        _mintTokens(owner, 1000);

        vm.startPrank(owner);
        uint tokenA_amount = 100 * 10**18;
        uint tokenB_amount = 100 * 10**6;

        // adding initial liquidity with both 100 tokens of each token
        DAI.approve(address(pool), tokenA_amount);
        USDC.approve(address(pool), tokenB_amount);

        (uint amountA, uint amountB, uint liquidity) = pool.addLiquidity(tokenA_amount, tokenB_amount, 0, 0, owner, block.timestamp+1);
        
        uint expectLiquidity = (SafeMath.sqrt(tokenA_amount * tokenB_amount)) - 1000; // decreasing minimum liquidity
        
        // initially all tokens are taken
        assertEq(amountA, tokenA_amount);   
        assertEq(amountB, tokenB_amount);             
        assertEq(liquidity, expectLiquidity);   // 99999999999000

        assertEq(pool.totalSupply(), expectLiquidity);
        assertEq(pool.getReserveA(), tokenA_amount);   // 100 * 1e18
        assertEq(pool.getReserveB(), tokenB_amount);   // 100 * 1e6

        assertEq(pool.balanceOf(owner), expectLiquidity);

        vm.stopPrank();
    }

    function test_secondAddLiquidity() external {
        test_addLiquidity();
        
        // adding second time liquidity with 100 tokens
        // both tokens are 100 so it accept all the tokens
        vm.startPrank(owner);
        uint m_totalSupply = pool.totalSupply();
        uint m_reserveA = pool.getReserveA();
        uint m_reserveB = pool.getReserveB();

        uint tokenA_amount = 100 * 10**18;
        uint tokenB_amount = 100 * 10**6;

        DAI.approve(address(pool), tokenA_amount);
        USDC.approve(address(pool), tokenB_amount);

        (uint amountA, uint amountB, uint liquidity) = pool.addLiquidity(tokenA_amount, tokenB_amount, 0, 0, owner, block.timestamp+1);
        
        uint expectLiquidity = SafeMath.min(
            (tokenA_amount * m_totalSupply) / (m_reserveA), (tokenB_amount * m_totalSupply) / (m_reserveB)
        );
        
        // due to not changing the price all the tokens are taken
        assertEq(amountA, tokenA_amount);   
        assertEq(amountB, tokenB_amount);             
        assertEq(liquidity, expectLiquidity);   // 99999999999000

        uint pastLiquidity = 99999999999000;

        assertEq(pool.totalSupply(), expectLiquidity + pastLiquidity);
        assertEq(pool.getReserveA(), 2 * tokenA_amount);   // 100 * 1e18
        assertEq(pool.getReserveB(), 2 * tokenB_amount);   // 100 * 1e6
        
        assertEq(pool.balanceOf(owner), pool.totalSupply());

        vm.stopPrank();
    }

    function test_mintTokens() public {
        _mintTokens(owner, 1000);
        assertEq(DAI.totalSupply(), 1000 * 10**18);
        assertEq(USDC.totalSupply(), 1000 * 10**6);
        
        assertEq(DAI.balanceOf(owner), 1000 * 10**18);
        assertEq(USDC.balanceOf(owner), 1000 * 10**6);
    }

    function test_fails_removeLiquidity() external {
        vm.startPrank(address(2));
        vm.expectRevert("SafeMath : Cannot divide by zero");
        pool.removeLiquidity(1000, 0, 0, address(2), block.timestamp + 1);
        vm.stopPrank();
    }

    function test_removeLiquidity() external {
        test_addLiquidity();
        vm.startPrank(owner);

        uint before_totalBalance = pool.totalSupply();

        console.log("Before owner DAI balance", DAI.balanceOf(owner));
        console.log("Before owner USDC balance", USDC.balanceOf(owner));
        console.log("Before pool DAI balance", DAI.balanceOf(address(pool)));
        console.log("Before pool USDC balance", USDC.balanceOf(address(pool)));
        
        // remove liquidity of 1 million wei
        (uint minA, uint minB) = pool._removeLiquidity(1000000, 0, 0);
        pool.removeLiquidity(1000000, minA, minB, owner, block.timestamp + 1);

        console.log("DAI return amount ", minA);
        console.log("USDC return amount ", minB);

        uint after_totalBalance = pool.totalSupply();
        assertEq(after_totalBalance, before_totalBalance - 1000000);

        console.log("After owner DAI balance", DAI.balanceOf(owner));
        console.log("After owner USDC balance", USDC.balanceOf(owner));
        console.log("After pool DAI balance", DAI.balanceOf(address(pool)));
        console.log("After pool USDC balance", USDC.balanceOf(address(pool)));
        
        vm.stopPrank();
    }

    function test_swapTokensExactInput() external {
        // owner added liquidity
        // currently pool has 100 dai and 100 usdc
        test_addLiquidity();

        console.log(pool.getReserveA());
        console.log(pool.getReserveB());
        
        address trader = address(2);
        vm.startPrank(trader);
        // both 100 tokens are minted to trader
        _mintTokens(trader, 100);
        
        DAI.approve(address(pool), 100 * 10**18);

        // enter dai 50 tokens, take usdc 50 tokens
        // 83112371912.178636
        pool.swapTokensExactInput(50 * 10**18, 0, address(DAI), address(USDC), trader, block.timestamp + 1);
        vm.stopPrank();
    }
}