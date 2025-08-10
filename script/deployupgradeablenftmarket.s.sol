// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Script, console} from "forge-std/Script.sol";
import "../src/MyToken.sol";
import "../src/upgradeable/MyERC721Upgradeable.sol";
import "../src/upgradeable/NFTMarketV1.sol";
import "../src/upgradeable/NFTMarketV2.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployUpgradeableNFTMarketScript is Script {
    MyToken public token;
    MyERC721Upgradeable public nft;
    NFTMarketV1 public marketV1Impl;
    NFTMarketV2 public marketV2Impl;
    ERC1967Proxy public marketProxy;
    NFTMarketV1 public marketV1;
    
    address public whitelistSigner;
    
    function setUp() public {}
    
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        whitelistSigner = deployer; // 使用部署者作为白名单签名者
        
        console.log("Deploying from address:", deployer);
        console.log("Deployer balance:", deployer.balance);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. 部署 MyToken
        token = new MyToken("UpgradeableMarketToken", "UMT", 0);
        console.log("MyToken deployed at:", address(token));
        
        // 2. 部署 MyERC721Upgradeable 实现合约
        MyERC721Upgradeable nftImpl = new MyERC721Upgradeable();
        console.log("MyERC721Upgradeable implementation deployed at:", address(nftImpl));
        
        // 3. 部署 MyERC721Upgradeable 代理合约
        bytes memory nftInitData = abi.encodeWithSelector(
            MyERC721Upgradeable.initialize.selector,
            "UpgradeableNFT",
            "UNFT"
        );
        ERC1967Proxy nftProxy = new ERC1967Proxy(address(nftImpl), nftInitData);
        nft = MyERC721Upgradeable(address(nftProxy));
        console.log("MyERC721Upgradeable proxy deployed at:", address(nftProxy));
        
        // 4. 部署 NFTMarketV1 实现合约
        marketV1Impl = new NFTMarketV1();
        console.log("NFTMarketV1 implementation deployed at:", address(marketV1Impl));
        
        // 5. 部署 NFTMarketV1 代理合约
        bytes memory marketInitData = abi.encodeWithSelector(
            NFTMarketV1.initialize.selector,
            address(token),
            address(nft),
            whitelistSigner
        );
        marketProxy = new ERC1967Proxy(address(marketV1Impl), marketInitData);
        marketV1 = NFTMarketV1(address(marketProxy));
        console.log("NFTMarket proxy deployed at:", address(marketProxy));
        
        // 6. 部署 NFTMarketV2 实现合约（用于后续升级）
        marketV2Impl = new NFTMarketV2();
        console.log("NFTMarketV2 implementation deployed at:", address(marketV2Impl));
        
        // 7. 铸造一些测试 NFT
        uint256 tokenId1 = nft.mint(deployer, "https://example.com/token/1");
        uint256 tokenId2 = nft.mint(deployer, "https://example.com/token/2");
        uint256 tokenId3 = nft.mint(deployer, "https://example.com/token/3");
        
        console.log("Minted NFT tokenIds:", tokenId1, tokenId2, tokenId3);
        
        vm.stopBroadcast();
        
        // 输出部署摘要
        console.log("\n=== Deployment Summary ===");
        console.log("MyToken Address:", address(token));
        console.log("MyERC721Upgradeable Implementation:", address(nftImpl));
        console.log("MyERC721Upgradeable Proxy:", address(nftProxy));
        console.log("NFTMarketV1 Implementation:", address(marketV1Impl));
        console.log("NFTMarketV2 Implementation:", address(marketV2Impl));
        console.log("NFTMarket Proxy:", address(marketProxy));
        console.log("Whitelist Signer:", whitelistSigner);
        console.log("\nNext steps:");
        console.log("1. Verify contracts on block explorer");
        console.log("2. Update README.md with contract addresses");
        console.log("3. Test upgrade functionality");
    }
    
    // 辅助函数：升级到 V2（可选）
    function upgradeToV2() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 升级到 V2
        marketV1.upgradeTo(address(marketV2Impl));
        console.log("Upgraded to NFTMarketV2");
        
        vm.stopBroadcast();
    }
}