// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Script, console} from "forge-std/Script.sol";
import "../src/EIP7702Delegate.sol";

contract DeployEIP7702DelegateScript is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deploying from address:", deployer);
        console.log("Deployer balance:", deployer.balance);
        
        vm.startBroadcast(deployerPrivateKey);

        // 部署 EIP7702Delegate 合约
        EIP7702Delegate delegate = new EIP7702Delegate();
        console.log("EIP7702Delegate deployed at:", address(delegate));
        
        vm.stopBroadcast();
        
        // 输出部署信息
        console.log("\n=== Deployment Summary ===");
        console.log("EIP7702Delegate Address:", address(delegate));
        console.log("Deployer:", deployer);
        console.log("Network: Sepolia Testnet");
        console.log("\nNext steps:");
        console.log("1. Verify the contract on Etherscan");
        console.log("2. Update frontend with the new delegate address");
        console.log("3. Test EIP-7702 delegation functionality");
    }
}