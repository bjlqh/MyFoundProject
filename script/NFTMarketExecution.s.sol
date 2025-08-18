// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Script, console} from "forge-std/Script.sol";
import "../src/MyToken.sol";
import "../src/MyERC721.sol";
import "../src/NFTMarket.sol";

contract NFTMarketExecutionScript is Script {
    // 已部署的合约地址
    address constant TOKEN_ADDRESS = 0xBBc0E474Cb264954ceA9B6714fAB45702200c59e;
    address constant NFT_ADDRESS = 0x2757c916E4C46950d2D6291C1F78E69139fB4888;
    address constant MARKET_ADDRESS = 0xc36666D6aecbdcb0793cfd1a9d832b8F24D5Bddc;
    
    MyToken token;
    MyERC721 nft;
    NFTMarket market;
    
    function run() public {
        // 连接到已部署的合约
        token = MyToken(TOKEN_ADDRESS);
        nft = MyERC721(NFT_ADDRESS);
        market = NFTMarket(MARKET_ADDRESS);
        
        // 执行步骤0：分发MyToken给两个用户
        distributeTokens();
        
        // 执行步骤1和2：SEPOLIA_PRIVATE_KEY1铸造2个NFT并上架
        executeStep1And2();
        
        // 执行步骤3和4：SEPOLIA_PRIVATE_KEY2铸造1个NFT并上架
        executeStep3And4();
        
        // 执行步骤5：SEPOLIA_PRIVATE_KEY1上架第一个NFT，价格5个MyToken
        executeStep5();
        
        // 执行步骤6：SEPOLIA_PRIVATE_KEY2上架NFT，价格10个MyToken
        executeStep6();
        
        // 执行步骤7：SEPOLIA_PRIVATE_KEY1购买SEPOLIA_PRIVATE_KEY2的NFT
        executeStep7();
    }
    
    function distributeTokens() internal {
        uint256 privateKey1 = vm.envUint("SEPOLIA_PRIVATE_KEY1");
        address user1 = vm.addr(privateKey1);
        address user2 = vm.addr(vm.envUint("SEPOLIA_PRIVATE_KEY2"));
        
        vm.startBroadcast(privateKey1);
        
        console.log("=== Step 0: Distribute MyTokens ===");
        console.log("Token owner (User1):", user1);
        console.log("User2:", user2);
        
        // 检查当前余额
        uint256 user1Balance = token.balanceOf(user1);
        uint256 user2Balance = token.balanceOf(user2);
        console.log("User1 MyToken balance:", user1Balance);
        console.log("User2 MyToken balance:", user2Balance);
        
        // 如果User2没有足够的代币，转一些给他
        if (user2Balance < 20 * 1e18) {
            token.transfer(user2, 50 * 1e18); // 转50个MyToken给User2
            console.log("Transferred 50 MyTokens to User2");
        }
        
        vm.stopBroadcast();
    }
    
    function executeStep1And2() internal {
        uint256 privateKey1 = vm.envUint("SEPOLIA_PRIVATE_KEY1");
        address user1 = vm.addr(privateKey1);
        
        vm.startBroadcast(privateKey1);
        
        console.log("=== Step 1-2: User1 mints 2 NFTs ===\n");
        console.log("User1 address:", user1);
        
        // 只铸造，不上架
        uint256 tokenId1 = nft.mint(user1, "https://example.com/nft1.json");
        console.log("Minted NFT tokenId:", tokenId1);
        
        uint256 tokenId2 = nft.mint(user1, "https://example.com/nft2.json");
        console.log("Minted NFT tokenId:", tokenId2);
        
        // 授权NFTMarket操作NFT
        nft.setApprovalForAll(address(market), true);
        console.log("Approved NFTMarket to operate NFTs");
        
        vm.stopBroadcast();
    }
    
    function executeStep3And4() internal {
        uint256 privateKey2 = vm.envUint("SEPOLIA_PRIVATE_KEY2");
        address user2 = vm.addr(privateKey2);
        
        vm.startBroadcast(privateKey2);
        
        console.log("=== Step 3-4: User2 mints 1 NFT ===\n");
        console.log("User2 address:", user2);
        
        // 只铸造，不上架
        uint256 tokenId3 = nft.mint(user2, "https://example.com/nft3.json");
        console.log("Minted NFT tokenId:", tokenId3);
        
        // 授权NFTMarket操作NFT
        nft.setApprovalForAll(address(market), true);
        console.log("Approved NFTMarket to operate NFTs");
        
        vm.stopBroadcast();
    }
    
    function executeStep5() internal {
        uint256 privateKey1 = vm.envUint("SEPOLIA_PRIVATE_KEY1");
        
        vm.startBroadcast(privateKey1);
        
        console.log("=== Step 5: User1 lists first NFT for 5 MyToken ===\n");
        
        // 上架第一个NFT，价格5个MyToken
        market.list(1, 5 * 10**18);
        console.log("Listed NFT 1 for 5 MyToken");
        
        vm.stopBroadcast();
    }
    
    function executeStep6() internal {
        uint256 privateKey2 = vm.envUint("SEPOLIA_PRIVATE_KEY2");
        
        vm.startBroadcast(privateKey2);
        
        console.log("=== Step 6: User2 lists NFT for 10 MyToken ===\n");
        
        // 上架NFT，价格10个MyToken
        market.list(3, 10 * 10**18);
        console.log("Listed NFT 3 for 10 MyToken");
        
        vm.stopBroadcast();
    }
    
    function executeStep7() internal {
        uint256 privateKey1 = vm.envUint("SEPOLIA_PRIVATE_KEY1");
        address user1 = vm.addr(privateKey1);
        
        vm.startBroadcast(privateKey1);
        
        console.log("=== Step 7: User1 buys User2's NFT with MyToken ===");
        console.log("User1 MyToken balance before:", token.balanceOf(user1));
        
        // 首先授权NFTMarket使用MyToken
        token.approve(MARKET_ADDRESS, 10 * 1e18);
        console.log("Approved NFTMarket to spend 10 MyToken");
        
        // 购买User2的NFT（tokenId 3，价格10个MyToken）
        market.buyNFT(3, 10 * 1e18);
        console.log("User1 bought NFT 3 for 10 MyToken");
        console.log("User1 MyToken balance after:", token.balanceOf(user1));
        
        vm.stopBroadcast();
    }
}