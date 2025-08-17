// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/flashswap/TokenA.sol";
import "../src/flashswap/TokenB.sol";
import "../src/flashswap/UniswapV2Factory.sol";
import "../src/flashswap/FlashSwapArbitrage.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract FlashSwapArbitrageTest is Test {
    TokenA public tokenA;
    TokenB public tokenB;
    UniswapV2Factory public factoryA;
    UniswapV2Factory public factoryB;
    FlashSwapArbitrage public flashSwap;
    
    address public poolA;
    address public poolB;
    address public owner;
    
    function setUp() public {
        owner = address(this);
        
        // 部署代币
        tokenA = new TokenA();
        tokenB = new TokenB();
        
        // 部署两个不同的Factory
        factoryA = new UniswapV2Factory(owner);
        factoryB = new UniswapV2Factory(owner);
        
        // 在不同的工厂中创建池子
        poolA = factoryA.createPair(address(tokenA), address(tokenB));
        poolB = factoryB.createPair(address(tokenA), address(tokenB));
        
        // 确定代币在pair中的顺序
        address token0A = UniswapV2Pair(poolA).token0();
        
        // 为PoolA添加流动性 (价格: 1 TokenA = 2 TokenB)
        uint256 amountA1 = 1000 * 1e18;
        uint256 amountB1 = 2000 * 1e18;
        
        // 根据token0/token1的顺序正确添加流动性
        if (token0A == address(tokenA)) {
            tokenA.transfer(poolA, amountA1);
            tokenB.transfer(poolA, amountB1);
        } else {
            tokenB.transfer(poolA, amountB1);
            tokenA.transfer(poolA, amountA1);
        }
        UniswapV2Pair(poolA).mint(owner);
        
        // 为PoolB添加流动性 (价格: 1 TokenA = 1.5 TokenB) - 创建套利机会
        uint256 amountA2 = 1000 * 1e18;
        uint256 amountB2 = 1500 * 1e18;  // 降低TokenB数量，使PoolB中TokenA更贵
        
        address token0B = UniswapV2Pair(poolB).token0();
        if (token0B == address(tokenA)) {
            tokenA.transfer(poolB, amountA2);
            tokenB.transfer(poolB, amountB2);
        } else {
            tokenB.transfer(poolB, amountB2);
            tokenA.transfer(poolB, amountA2);
        }
        UniswapV2Pair(poolB).mint(owner);
        
        // 部署闪电兑换合约
        flashSwap = new FlashSwapArbitrage(address(factoryA), address(factoryB));
    }

    event FlashSwapExecuted(
        address indexed poolA,
        address indexed poolB,
        address tokenA,
        address tokenB,
        uint256 amountBorrowed,
        uint256 profit
    );
    
    
    function testFlashSwapArbitrage() public {
        // 记录初始余额
        uint256 initialTokenABalance = tokenA.balanceOf(owner);
        uint256 initialTokenBBalance = tokenB.balanceOf(owner);
        
        console.log("=== Initial Balances ===");
        console.log("Owner TokenA balance:", initialTokenABalance / 1e18);
        console.log("Owner TokenB balance:", initialTokenBBalance / 1e18);
        
        // 执行闪电兑换套利
        uint256 borrowAmount = 50 * 1e18; // 借50个TokenA
        
        console.log("\n=== Executing Flash Swap Arbitrage ===");
        console.log("Borrowing", borrowAmount / 1e18, "TokenA from PoolB");
        
        // 监听事件
        vm.expectEmit(true, true, true, false);
        emit FlashSwapExecuted(
            poolB, poolA, address(tokenA), address(tokenB), borrowAmount, 0
        );
        
        // 修改：从PoolB借TokenA，在PoolA交换
        flashSwap.executeFlashSwap(
            poolB,      // 从PoolB借TokenA（价格高的池子）
            poolA,      // 在PoolA交换（价格低的池子）
            address(tokenA),
            address(tokenB),
            borrowAmount
        );
        
        // 检查最终余额
        uint256 finalTokenABalance = tokenA.balanceOf(owner);
        uint256 finalTokenBBalance = tokenB.balanceOf(owner);
        
        console.log("\n=== Final Balances ===");
        console.log("Owner TokenA balance:", finalTokenABalance / 1e18);
        console.log("Owner TokenB balance:", finalTokenBBalance / 1e18);
        
        // 验证套利成功
        assertTrue(finalTokenBBalance > initialTokenBBalance, "Should have profit in TokenB");
        
        console.log("\n=== Arbitrage Profit ===");
        console.log("TokenB profit:", (finalTokenBBalance - initialTokenBBalance) / 1e18);
    }
    
    function testPoolPrices() public view {
        // 检查两个池子的价格差异
        (uint112 reserveA0, uint112 reserveA1,) = UniswapV2Pair(poolA).getReserves();
        (uint112 reserveB0, uint112 reserveB1,) = UniswapV2Pair(poolB).getReserves();
        
        console.log("\n=== Pool Reserves ===");
        console.log("PoolA - Reserve0:", reserveA0 / 1e18, "Reserve1:", reserveA1 / 1e18);
        console.log("PoolB - Reserve0:", reserveB0 / 1e18, "Reserve1:", reserveB1 / 1e18);
        
        // 确定哪个是TokenA，哪个是TokenB
        address token0 = UniswapV2Pair(poolA).token0();
        bool isToken0A = token0 == address(tokenA);
        
        uint256 tokenAReserveA = isToken0A ? reserveA0 : reserveA1;
        uint256 tokenBReserveA = isToken0A ? reserveA1 : reserveA0;
        uint256 tokenAReserveB = isToken0A ? reserveB0 : reserveB1;
        uint256 tokenBReserveB = isToken0A ? reserveB1 : reserveB0;
        
        console.log("\n=== Actual Token Reserves ===");
        console.log("PoolA - TokenA:", tokenAReserveA / 1e18, "TokenB:", tokenBReserveA / 1e18);
        console.log("PoolB - TokenA:", tokenAReserveB / 1e18, "TokenB:", tokenBReserveB / 1e18);
        
        // 计算价格比率 (避免除零)
        if (tokenAReserveA > 0 && tokenAReserveB > 0) {
            uint256 priceA = (tokenBReserveA * 1e18) / tokenAReserveA;
            uint256 priceB = (tokenBReserveB * 1e18) / tokenAReserveB;
            
            console.log("\n=== Prices ===");
            console.log("PoolA price (TokenB per TokenA):", priceA / 1e18);
            console.log("PoolB price (TokenB per TokenA):", priceB / 1e18);
            
            // 修改断言：PoolA价格应该高于PoolB，这样从PoolA借TokenA在PoolB卖出才有利润
            assertTrue(priceA > priceB, "PoolA should have higher price than PoolB for arbitrage");
        }
    }
}