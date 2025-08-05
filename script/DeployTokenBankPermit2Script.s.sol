// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Script, console} from "forge-std/Script.sol";
import "../src/bank/TokenBank.sol";
import "../src/MyToken.sol";
import {Permit2} from "@permit2/Permit2.sol";

contract DeployTokenBankPermit2Script is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        //uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        //address deployer = vm.addr(deployerPrivateKey);
        
        // 部署 Permit2 合约
        Permit2 permit2 = new Permit2();
        console.log("Permit2 deployed at:", address(permit2));
        
        // 部署 ERC20
        MyToken token = new MyToken("MyToken","MT");
        console.log("token address:", address(token));
        
        // 部署 TokenBank（传入 token 和 permit2 地址）
        TokenBank bank = new TokenBank(address(token), address(permit2));
        console.log("bank address:", address(bank));

        vm.stopBroadcast();
    }
}