// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "../lib/permit2/src/Permit2.sol";

contract DeployPermit2Script is Script {
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);

        // 部署 Permit2 合约
        Permit2 permit2 = new Permit2();
        console.log("Permit2 deployed at:", address(permit2));

        vm.stopBroadcast();
    }
} 