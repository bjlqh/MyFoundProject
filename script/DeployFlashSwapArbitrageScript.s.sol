// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "../src/arbitrage/FlashSwapArbitrage.sol";
import "../src/arbitrage/TestTokenA.sol";
import "../src/arbitrage/TestTokenB.sol";

contract DeployFlashSwapArbitrageScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        // Sepolia测试网上的Uniswap V2地址
        address UNISWAP_V2_FACTORY = 0x7E0987E5b3a30e3f2828572Bb659A548460a3003;
        address UNISWAP_V2_ROUTER = 0xC532a74256D3Db42D0Bf7a0400fEFDbad7694008;
        
        // 部署测试代币
        TestTokenA tokenA = new TestTokenA();
        TestTokenB tokenB = new TestTokenB();
        
        console.log("TestTokenA deployed at:", address(tokenA));
        console.log("TestTokenB deployed at:", address(tokenB));
        
        // 部署闪电兑换套利合约
        FlashSwapArbitrage arbitrage = new FlashSwapArbitrage(
            UNISWAP_V2_FACTORY,
            UNISWAP_V2_ROUTER,
            UNISWAP_V2_ROUTER // 在实际场景中，这应该是不同的router
        );
        
        console.log("FlashSwapArbitrage deployed at:", address(arbitrage));
        
        vm.stopBroadcast();
    }
}