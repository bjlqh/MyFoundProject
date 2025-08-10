// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../src/MyToken.sol";
import "../src/upgradeable/MyERC721Upgradeable.sol";
import "../src/upgradeable/NFTMarketV1.sol";
import "../src/upgradeable/NFTMarketV2.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract UpgradeableNFTMarketTest is Test {
    using ECDSA for bytes32;
    
    MyToken public token;
    MyERC721Upgradeable public nft;
    NFTMarketV1 public marketV1;
    NFTMarketV2 public marketV2;
    ERC1967Proxy public marketProxy;
    
    address public owner;
    address public user1;
    address public user2;
    address public whitelistSigner;
    
    uint256 public constant INITIAL_TOKEN_SUPPLY = 1000 * 1e18;
    uint256 public constant NFT_PRICE = 100 * 1e18;
    
    uint256 private whitelistSignerPrivateKey;
    uint256 private user1PrivateKey;
    
    function setUp() public {
        owner = address(this);
        
        // 创建白名单签名者
        whitelistSignerPrivateKey = 0x1234;
        whitelistSigner = vm.addr(whitelistSignerPrivateKey);
        
        // 创建user1的私钥和地址
        user1PrivateKey = 0x5678;
        user1 = vm.addr(user1PrivateKey);
        
        // 创建user2
        user2 = makeAddr("user2");
        
        // 部署 MyToken
        token = new MyToken("MyToken", "MTK", 0);
        
        // 部署 MyERC721Upgradeable
        MyERC721Upgradeable nftImpl = new MyERC721Upgradeable();
        bytes memory nftInitData = abi.encodeWithSelector(
            MyERC721Upgradeable.initialize.selector,
            "MyNFT",
            "MNFT"
        );
        ERC1967Proxy nftProxy = new ERC1967Proxy(address(nftImpl), nftInitData);
        nft = MyERC721Upgradeable(address(nftProxy));
        
        // 部署 NFTMarketV1
        NFTMarketV1 marketV1Impl = new NFTMarketV1();
        bytes memory marketInitData = abi.encodeWithSelector(
            NFTMarketV1.initialize.selector,
            address(token),
            address(nft),
            whitelistSigner
        );
        marketProxy = new ERC1967Proxy(address(marketV1Impl), marketInitData);
        marketV1 = NFTMarketV1(address(marketProxy));
        
        // 给用户分发代币
        token.transfer(user1, 500 * 1e18);
        token.transfer(user2, 500 * 1e18);
        
        // 铸造NFT给用户
        nft.mint(user1, "https://example.com/token/1");
        nft.mint(user1, "https://example.com/token/2");
        nft.mint(user2, "https://example.com/token/3");
    }
    
    function testV1BasicFunctionality() public {
        // 测试V1的基本功能
        uint256 tokenId = 1;
        
        vm.startPrank(user1);
        
        // 授权NFT给市场
        nft.approve(address(marketV1), tokenId);
        
        // 上架NFT
        marketV1.list(tokenId, NFT_PRICE);
        
        // 检查上架状态
        (address seller, uint256 price) = marketV1.listings(tokenId);
        assertEq(seller, user1);
        assertEq(price, NFT_PRICE);
        assertEq(marketV1.getListedTokenIdsLength(), 1);
        
        vm.stopPrank();
        
        // 用户2购买NFT
        vm.startPrank(user2);
        token.approve(address(marketV1), NFT_PRICE);
        marketV1.buyNFT(tokenId, NFT_PRICE);
        vm.stopPrank();
        
        // 检查购买后状态
        assertEq(nft.ownerOf(tokenId), user2);
        assertEq(marketV1.getListedTokenIdsLength(), 0);
    }
    
    function testUpgradeToV2() public {
        // 在升级前设置一些状态
        uint256 tokenId = 1;
        
        vm.startPrank(user1);
        nft.setApprovalForAll(address(marketV1), true);
        marketV1.list(tokenId, NFT_PRICE);
        vm.stopPrank();
        
        // 记录升级前的状态
        (address sellerBefore, uint256 priceBefore) = marketV1.listings(tokenId);
        uint256 listedLengthBefore = marketV1.getListedTokenIdsLength();
        address nftAddressBefore = address(marketV1.nft());
        address tokenAddressBefore = address(marketV1.token());
        address whitelistSignerBefore = marketV1.whitelistSigner();
        
        // 升级到V2
        NFTMarketV2 marketV2Impl = new NFTMarketV2();
        marketV1.upgradeTo(address(marketV2Impl));
        
        // 将代理转换为V2接口
        marketV2 = NFTMarketV2(address(marketProxy));
        
        // 验证升级后状态保持一致
        (address sellerAfter, uint256 priceAfter) = marketV2.listings(tokenId);
        assertEq(sellerAfter, sellerBefore, "Seller should remain the same");
        assertEq(priceAfter, priceBefore, "Price should remain the same");
        assertEq(marketV2.getListedTokenIdsLength(), listedLengthBefore, "Listed length should remain the same");
        assertEq(address(marketV2.nft()), nftAddressBefore, "NFT address should remain the same");
        assertEq(address(marketV2.token()), tokenAddressBefore, "Token address should remain the same");
        assertEq(marketV2.whitelistSigner(), whitelistSignerBefore, "Whitelist signer should remain the same");
        
        console.log("[SUCCESS] Upgrade successful - all state preserved");
    }
    
    function testV2SignatureListing() public {
        // 升级到V2
        NFTMarketV2 marketV2Impl = new NFTMarketV2();
        marketV1.upgradeTo(address(marketV2Impl));
        marketV2 = NFTMarketV2(address(marketProxy));
        
        uint256 tokenId = 2;
        uint256 price = NFT_PRICE;
        uint256 deadline = block.timestamp + 1 hours;
        
        // user1设置setApprovalForAll
        vm.prank(user1);
        // 用户授权市场合约管理其所有NFT
        nft.setApprovalForAll(address(marketV2), true);
        
        // 创建签名
        bytes32 messageHash = keccak256(abi.encodePacked(
            tokenId,
            price,
            deadline,
            address(marketV2)
        ));
        bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(user1PrivateKey, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        
        // 任何人都可以使用签名上架NFT
        vm.prank(user2);
        marketV2.listWithSignature(tokenId, price, deadline, signature);
        
        // 验证上架成功
        (address seller, uint256 listedPrice) = marketV2.listings(tokenId);
        assertEq(seller, user1);
        assertEq(listedPrice, price);
        assertEq(marketV2.getListedTokenIdsLength(), 1);
        
        console.log("[SUCCESS] Signature listing successful");
    }
    
    function testV2SignatureListingReplayProtection() public {
        // 升级到V2
        NFTMarketV2 marketV2Impl = new NFTMarketV2();
        marketV1.upgradeTo(address(marketV2Impl));
        marketV2 = NFTMarketV2(address(marketProxy));
        
        uint256 tokenId = 2;
        uint256 price = NFT_PRICE;
        uint256 deadline = block.timestamp + 1 hours;
        
        vm.prank(user1);
        nft.setApprovalForAll(address(marketV2), true);
        
        // 创建签名
        bytes32 messageHash = keccak256(abi.encodePacked(
            tokenId,
            price,
            deadline,
            address(marketV2)
        ));
        bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(user1PrivateKey, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        
        // 第一次使用签名
        vm.prank(user2);
        marketV2.listWithSignature(tokenId, price, deadline, signature);
        
        // 购买NFT以便重新测试
        vm.startPrank(user2);
        token.approve(address(marketV2), price);
        marketV2.buyNFT(tokenId, price);
        vm.stopPrank();
        
        // 将NFT转回给user1
        vm.prank(user2);
        nft.transferFrom(user2, user1, tokenId);
        
        // 尝试重复使用相同签名应该失败
        vm.prank(user2);
        vm.expectRevert(NFTMarketV2.ListingSignatureAlreadyUsed.selector);
        marketV2.listWithSignature(tokenId, price, deadline, signature);
        
        console.log("[SUCCESS] Replay protection working correctly");
    }
    
    function testV2InvalidSignature() public {
        // 升级到V2
        NFTMarketV2 marketV2Impl = new NFTMarketV2();
        marketV1.upgradeTo(address(marketV2Impl));
        marketV2 = NFTMarketV2(address(marketProxy));
        
        uint256 tokenId = 2;
        uint256 price = NFT_PRICE;
        uint256 deadline = block.timestamp + 1 hours;
        
        vm.prank(user1);
        nft.setApprovalForAll(address(marketV2), true);
        
        // 使用错误的私钥创建签名
        bytes32 messageHash = keccak256(abi.encodePacked(
            tokenId,
            price,
            deadline,
            address(marketV2)
        ));
        bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(whitelistSignerPrivateKey, ethSignedMessageHash); // 错误的私钥
        bytes memory signature = abi.encodePacked(r, s, v);
        
        // 应该失败
        vm.prank(user2);
        vm.expectRevert(NFTMarketV2.InvalidSignature.selector);
        marketV2.listWithSignature(tokenId, price, deadline, signature);
        
        console.log("[SUCCESS] Invalid signature rejected correctly");
    }
    
    function testV2WithoutApprovalForAll() public {
        // 升级到V2
        NFTMarketV2 marketV2Impl = new NFTMarketV2();
        marketV1.upgradeTo(address(marketV2Impl));
        marketV2 = NFTMarketV2(address(marketProxy));
        
        uint256 tokenId = 2;
        uint256 price = NFT_PRICE;
        uint256 deadline = block.timestamp + 1 hours;
        
        // 不设置setApprovalForAll
        
        // 创建签名
        bytes32 messageHash = keccak256(abi.encodePacked(
            tokenId,
            price,
            deadline,
            address(marketV2)
        ));
        bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(user1PrivateKey, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        
        // 应该失败
        vm.prank(user2);
        vm.expectRevert(NFTMarketV2.NotApprovedForAll.selector);
        marketV2.listWithSignature(tokenId, price, deadline, signature);
        
        console.log("[SUCCESS] Not approved for all rejected correctly");
    }
    
    function testCompleteUpgradeWorkflow() public {
        console.log("\n=== Testing Complete Upgrade Workflow ===");
        
        // 1. 在V1中创建一些状态
        console.log("1. Setting up initial state in V1...");
        uint256 tokenId1 = 1;
        uint256 tokenId2 = 2;
        uint256 tokenId3 = 3;
        
        vm.startPrank(user1);
        nft.setApprovalForAll(address(marketV1), true);
        marketV1.list(tokenId1, NFT_PRICE);
        marketV1.list(tokenId2, NFT_PRICE * 2);
        vm.stopPrank();
        
        vm.startPrank(user2);
        nft.setApprovalForAll(address(marketV1), true);
        marketV1.list(tokenId3, NFT_PRICE * 3);
        vm.stopPrank();
        
        assertEq(marketV1.getListedTokenIdsLength(), 3);
        console.log("   - Listed 3 NFTs in V1");
        
        // 2. 升级到V2
        console.log("2. Upgrading to V2...");
        NFTMarketV2 marketV2Impl = new NFTMarketV2();
        marketV1.upgradeTo(address(marketV2Impl));
        marketV2 = NFTMarketV2(address(marketProxy));
        console.log("   - Upgrade completed");
        
        // 3. 验证状态保持
        console.log("3. Verifying state preservation...");
        assertEq(marketV2.getListedTokenIdsLength(), 3);
        (address seller1, uint256 price1) = marketV2.listings(tokenId1);
        (address seller2, uint256 price2) = marketV2.listings(tokenId2);
        (address seller3, uint256 price3) = marketV2.listings(tokenId3);
        assertEq(seller1, user1);
        assertEq(price1, NFT_PRICE);
        assertEq(seller2, user1);
        assertEq(price2, NFT_PRICE * 2);
        assertEq(seller3, user2);
        assertEq(price3, NFT_PRICE * 3);
        console.log("   - All state preserved correctly");
        
        // 4. 测试V2新功能：签名上架
        console.log("4. Testing V2 signature listing...");
        
        // 铸造一个新的NFT给user1用于签名上架测试
        uint256 newTokenId = nft.mint(user1, "https://example.com/token/4");
        uint256 deadline = block.timestamp + 1 hours;
        
        // user1设置授权
        vm.prank(user1);
        nft.setApprovalForAll(address(marketV2), true);
        
        // 生成签名
        bytes32 messageHash = keccak256(abi.encodePacked(
            newTokenId,
            NFT_PRICE,
            deadline,
            address(marketV2)
        ));
        bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash();
        
        // 使用user1的私钥签名
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(user1PrivateKey, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        
        // 任何人都可以使用签名上架NFT
        vm.prank(user2);
        marketV2.listWithSignature(newTokenId, NFT_PRICE, deadline, signature);
        
        assertEq(marketV2.getListedTokenIdsLength(), 4);
        console.log("   - Signature listing working correctly");
        
        // 5. 测试旧功能仍然工作
        console.log("5. Testing V1 functionality still works...");
        vm.startPrank(user2);
        token.approve(address(marketV2), NFT_PRICE * 2);
        marketV2.buyNFT(tokenId2, NFT_PRICE * 2);
        vm.stopPrank();
        
        assertEq(nft.ownerOf(tokenId2), user2);
        assertEq(marketV2.getListedTokenIdsLength(), 3);
        console.log("   - V1 functionality preserved");
        
        console.log("\n[SUCCESS] Complete upgrade workflow successful!");
    }
}