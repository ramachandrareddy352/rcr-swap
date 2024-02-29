// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "forge-std/Vm.sol";

import {ERC20} from "../helper/ERC20.sol";
import {IERC20} from "../helper/IERC20.sol";

import {Factory} from "../../src/Factory.sol";
import {IFactory} from "../../src/interfaces/IFactory.sol";

/**
 * Here we take total 3 ERC20 tokens and one pair(1,2) is stable prices and other pair(1,3) is unstable prices.
 * 
 */
contract FactoryTest is Test {

    ERC20 internal USDC;
    ERC20 internal DAI;
    ERC20 internal WETH;

    Factory internal factory;

    address internal owner = address(1);

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

    function setUp() public {
        USDC = new ERC20("TOKEN-A", "USDC", 6);
        DAI = new ERC20("TOKEN-B", "DAI", 18);
        WETH = new ERC20("TOKEN-C", "WETH", 18);

        uint[] memory tick = new uint[](1);
        tick[0] = 100;
        address[] memory pair1 = new address[](1);
        pair1[0] = address(USDC);
        address[] memory pair2 = new address[](1);
        pair2[0] = address(DAI);
        
        vm.prank(owner);
        factory = new Factory(pair1, pair2 , tick);   // tick is set to 100
    }

    function test_constructor() external {
        assertEq(factory.owner(), address(1));
        assertEq(factory.getTick(address(USDC), address(DAI)), 100);
    }

    function test_fail_createPool() external {
        vm.expectRevert("Factory : Identical tokens");
        factory.createPool(address(USDC), address(USDC), 3000);

        vm.expectRevert("Factory : Invalid zero address");
        factory.createPool(address(0), address(USDC), 3000);

        
        vm.expectRevert("Factory : Invalid fee");
        factory.createPool(address(DAI), address(USDC), 0);
        
        factory.createPool(address(DAI), address(USDC), 3000);

        vm.expectRevert("Factory : Pool alreday exist");
        factory.createPool(address(DAI), address(USDC), 3000);
    }
    
    function _createPools() private returns (address pool1, address pool2) {
        vm.startPrank(owner);

        // creating pool with 0.3% fee
        pool1 = factory.createPool(address(DAI), address(USDC), 3000);

        // creating pool with 0.5% fee
        pool2 = factory.createPool(address(DAI), address(WETH), 5000);

        vm.stopPrank();
    }

    function test_poolStruct() external {
        (address pool1, address pool2) = _createPools();

        _Pool memory struct1 = _Pool(address(DAI), address(USDC), 3000);
        _Pool memory struct2 = _Pool(address(DAI), address(WETH), 5000);
        
        // check the struct of pools
        assertEq(factory.getPoolData(pool1).tokenA, struct1.tokenA);
        assertEq(factory.getPoolData(pool1).tokenB, struct1.tokenB);
        assertEq(factory.getPoolData(pool1).fee, struct1.fee);
        
        assertEq(factory.getPoolData(pool2).tokenA, struct2.tokenA);
        assertEq(factory.getPoolData(pool2).tokenB, struct2.tokenB);
        assertEq(factory.getPoolData(pool2).fee, struct2.fee);
    }

    function test_ownerPools() external {
        _createPools();

        uint256[] memory ownerPools = factory.getOwnerPools(owner);
        
        // check the pool count
        assertEq(factory.s_poolCount(), 2);

        // verify the owner pool numbers
        assertEq(ownerPools[0], 1);
        assertEq(ownerPools[1], 2);
    }

    function test_poolTicks() external {
        assertEq(factory.getTick(address(DAI), address(USDC)), 100);
        assertEq(factory.getTick(address(DAI), address(WETH)), 0);
    }

    function test_poolCount() external {
        _createPools();

        _Pool memory struct1 = _Pool(address(DAI), address(USDC), 3000);
        _Pool memory struct2 = _Pool(address(DAI), address(WETH), 5000);
        
        // check the struct of pools
        assertEq(factory.getPool(1).tokenA, struct1.tokenA);
        assertEq(factory.getPool(1).tokenB, struct1.tokenB);
        assertEq(factory.getPool(1).fee, struct1.fee);
        
        assertEq(factory.getPool(2).tokenA, struct2.tokenA);
        assertEq(factory.getPool(2).tokenB, struct2.tokenB);
        assertEq(factory.getPool(2).fee, struct2.fee);

        assertEq(factory.getAllPoolsAddress().length, 2);
    }

    function test_getPair() external {
        (address pool1, address pool2) = _createPools();
        
        assertEq(factory.getPair(address(DAI), address(USDC), 3000), pool1);
        assertEq(factory.getPair(address(DAI), address(WETH), 5000), pool2);
    }

    function test_getInvalidPair() external {
        // for not exist pair it shows zero address
        assertEq(factory.getPair(address(WETH), address(USDC), 3000), address(0));
    }
    
    function test_fail_invalidOwnerCall() external {
        vm.startPrank(address(2));

        uint[] memory tick = new uint[](1);
        tick[0] = 100;
        address[] memory pair1 = new address[](1);
        pair1[0] = address(USDC);
        address[] memory pair2 = new address[](1);
        pair2[0] = address(DAI);

        vm.expectRevert();
        factory.setTicks(pair1, pair2, tick);

        vm.stopPrank();
    }

    function test_constants() external {
        assertEq(factory.MAX_POOL_FEE(), 10000);
        assertEq(factory.MIN_POOL_FEE(), 100);
        assertEq(factory.MAX_TICK(), 100);
    }

    function test_transferOwner() external {
        vm.prank(owner);
        factory.transferOwnership(address(10));

        assertEq(factory.owner(), address(10));
    }
}