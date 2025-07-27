// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "../src/MyToken.sol";
import "../src/MyERC721.sol";
import "../src/NFTMarket.sol";
import "../src/bank/TokenBank.sol";
import "../src/bank/SimplePermit2.sol";

contract DeployEIP712Script is Script {
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);

        // 部署Token合约
        MyToken token = new MyToken("MyEIP712Token", "MET");
        console.log("Token deployed at:", address(token));

        // 部署NFT合约
        MyERC721 nft = new MyERC721("MyEIP712NFT", "MENFT");
        console.log("NFT deployed at:", address(nft));

        // 部署 Permit2 合约
        SimplePermit2 permit2 = new SimplePermit2();
        console.log("Permit2 deployed at:", address(permit2));

        // 部署TokenBank合约 (包含 Permit2 地址)
        TokenBank tokenBank = new TokenBank(address(token), address(permit2));
        console.log("TokenBank deployed at:", address(tokenBank));

        // 部署NFTMarket合约 (使用deployer作为白名单签名者)
        NFTMarket nftMarket = new NFTMarket(address(token), address(nft), deployer);
        console.log("NFTMarket deployed at:", address(nftMarket));

        // 铸造一些NFT
        uint256 tokenId1 = nft.mint(deployer, "ipfs://QmToken1");
        uint256 tokenId2 = nft.mint(deployer, "ipfs://QmToken2");
        console.log("NFT TokenId1 minted:", tokenId1);
        console.log("NFT TokenId2 minted:", tokenId2);

        vm.stopBroadcast();
    }
}