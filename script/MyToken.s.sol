// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Script, console} from "forge-std/Script.sol";
import {MyToken} from "../src/MyToken.sol";

contract MyTokenScript is Script {
    MyToken public token;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        token = new MyToken("MyTokennnnnnn","MT", 0);

        vm.stopBroadcast();
    }
}