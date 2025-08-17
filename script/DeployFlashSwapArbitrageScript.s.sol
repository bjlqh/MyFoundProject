// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/flashswap/TokenA.sol";
import "../src/flashswap/TokenB.sol";
import "../src/flashswap/UniswapV2Factory.sol";
import "../src/flashswap/FlashSwapArbitrage.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DeployFlashSwapArbitrageScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("SEPOLIA_PRIVATE_KEY1");
        vm.startBroadcast(deployerPrivateKey);
        
        address deployer = vm.addr(deployerPrivateKey);
        console.log("Deployer:", deployer);
        
        // 1. 部署代币
        TokenA tokenA = new TokenA();
        TokenB tokenB = new TokenB();
        console.log("TokenA deployed at:", address(tokenA));
        console.log("TokenB deployed at:", address(tokenB));
        
        // 2. 部署Factory
        UniswapV2Factory factoryA = new UniswapV2Factory(deployer);
        UniswapV2Factory factoryB = new UniswapV2Factory(deployer);
        console.log("FactoryA deployed at:", address(factoryA));
        console.log("FactoryB deployed at:", address(factoryB));
        
        // 3. 创建两个流动性池
        address poolA = factoryA.createPair(address(tokenA), address(tokenB));
        address poolB = factoryB.createPair(address(tokenA), address(tokenB));
        console.log("PoolA created at:", poolA);
        console.log("PoolB created at:", poolB);
        
        // 4. 为PoolA添加流动性 (价格: 1 TokenA = 2 TokenB)
        uint256 amountA1 = 1000 * 1e18;
        uint256 amountB1 = 2000 * 1e18;
        
        tokenA.transfer(poolA, amountA1);
        tokenB.transfer(poolA, amountB1);
        UniswapV2Pair(poolA).mint(deployer);
        
        console.log("PoolA liquidity added: 1000 TokenA, 2000 TokenB");
        
        // 5. 为PoolB添加流动性 (价格: 1 TokenA = 2.1 TokenB) - 创造套利机会
        uint256 amountA2 = 1000 * 1e18;
        uint256 amountB2 = 2100 * 1e18;
        
        tokenA.transfer(poolB, amountA2);
        tokenB.transfer(poolB, amountB2);
        UniswapV2Pair(poolB).mint(deployer);
        
        console.log("PoolB liquidity added: 1000 TokenA, 2100 TokenB");
        
        // 6. 部署闪电兑换套利合约
        FlashSwapArbitrage flashSwap = new FlashSwapArbitrage(address(factoryA), address(factoryB));
        console.log("FlashSwapArbitrage deployed at:", address(flashSwap));
        
        vm.stopBroadcast();
        
        // 输出部署信息
        console.log("\n=== Deployment Summary ===");
        console.log("TokenA:", address(tokenA));
        console.log("TokenB:", address(tokenB));
        console.log("FactoryA:", address(factoryA));
        console.log("FactoryB:", address(factoryB));
        console.log("PoolA (1:2 ratio):", poolA);
        console.log("PoolB (1:2.1 ratio):", poolB);
        console.log("FlashSwapArbitrage:", address(flashSwap));
        console.log("\nArbitrage opportunity: Buy TokenA from PoolA, sell to PoolB");
    }
}