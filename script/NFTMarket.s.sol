// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Script, console} from "forge-std/Script.sol";
import "../src/MyToken.sol";
import "../src/MyERC721.sol";
import "../src/NFTMarket.sol";

contract NFTMarketScript is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("SEPOLIA_PRIVATE_KEY1");
        vm.startBroadcast(deployerPrivateKey);
        address deployer = vm.addr(deployerPrivateKey);
        console.log("Deployer:", deployer);
        
        //部署ERC20
        MyToken token = new MyToken("MyToken", "MT", 0);
        console.log("token address:", address(token));

        //部署ERC721
        MyERC721 nft = new MyERC721("MyNFT", "MNFT");
        console.log("nft address:", address(nft));

        //部署NFTMarket
        NFTMarket market = new NFTMarket(
            address(token),
            address(nft),
            address(0x123)
        );
        console.log("market address:", address(market));

        vm.stopBroadcast();
    }
}
