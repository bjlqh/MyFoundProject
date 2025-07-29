// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Script, console} from "forge-std/Script.sol";
import {MemeFactory} from "../src/factory/MemeFactory.sol";

contract DeployMemeFactoryScript is Script {
    MemeFactory public factory;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        console.log("Deploying MemeFactory...");
        
        factory = new MemeFactory();
        
        console.log("MemeFactory deployed successfully!");
        console.log("Factory address:", address(factory));
        console.log("Implementation address:", address(factory.memeTokenImpl()));
        console.log("Owner address:", factory.owner());

        vm.stopBroadcast();
    }
} 