// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Script, console} from "forge-std/Script.sol";
import "../src/bank/TokenBank.sol";
import "../src/MyToken.sol";

contract TokenBankScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        //部署ERC20
        MyToken token = new MyToken("MyToken","MT");
        console.log("token address:",address(token));
        
        //部署TokenBank
        TokenBank bank = new TokenBank(address(token),address(0x0));
        console.log("bank address:",address(bank));

        vm.stopBroadcast();
    }
}