// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/flashswap/FlashSwapArbitrage.sol";
import "../src/flashswap/TokenA.sol";
import "../src/flashswap/TokenB.sol";

contract ExecuteArbitrageScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("SEPOLIA_PRIVATE_KEY1");
        vm.startBroadcast(deployerPrivateKey);
        
        // 已部署的合约地址
        address flashSwapAddress = 0x4A51F23d1fC6a346804559F575172f9458803542;
        address poolA = 0xbB359E9b350243C0549D268D7A1eFbc908E9D1fE;
        address poolB = 0xe61CF80bfFC2eE14Ebb589269AA836EdA32B4844;
        address tokenA = 0x3D6B349b8d8BdDc039b3d897F4Efa0C3AA46dE88;
        address tokenB = 0x1b6748B34c3734f9cf0A33497f0c838c78Dba446;
        
        FlashSwapArbitrage flashSwap = FlashSwapArbitrage(flashSwapAddress);
        
        console.log("Executing arbitrage...");
        console.log("Borrowing 1 TokenA from PoolA");
        console.log("Swapping in PoolB for higher price");
        
        // 执行套利：借1个TokenA
        uint256 borrowAmount = 1 ether;
        flashSwap.executeFlashSwap(poolA, poolB, tokenA, tokenB, borrowAmount);
        
        console.log("Arbitrage executed successfully!");
        
        vm.stopBroadcast();
    }
}