// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import "../src/MyToken.sol";
import "../src/MyERC721.sol";
import "../src/NFTMarket.sol";

contract NFTMarketScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        //部署ERC20
        MyToken token = new MyToken("MyToken","MT");
        console.log("token address:",address(token));
        
        //部署ERC721
        MyERC721 nft = new MyERC721("MyNFT","MNFT");
        console.log("nft address:",address(nft));

        //部署NFTMarket
        NFTMarket market = new NFTMarket(address(token),address(nft), address(0x123));
        console.log("market address:",address(market));

        vm.stopBroadcast();
    }
}