// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console.sol";
import "forge-std/Test.sol";
import "../src/MyToken.sol";
import "../src/MyERC721.sol";
import "../src/NFTMarket.sol";
import "../src/bank/TokenBank.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract EIP721 is Test {
    //对bytes32类型的变量使用ECDSA库中的函数
    using ECDSA for bytes32;

    MyToken public token;
    MyERC721 public nft;
    TokenBank public tokenBank;
    NFTMarket public nftMarket;

    address public owner;
    address public user1;
    address public user2;
    address public whitelistSigner;

    uint256 public ownerPrivateKey;
    uint256 public user1PrivateKey;
    uint256 public user2PrivateKey;
    uint256 public whitelistSignerPrivateKey;

    function setUp() public {
        //生成私钥
        ownerPrivateKey = 0xA11CE;
        user1PrivateKey = 0xB0B;
        user2PrivateKey = 0xC0C;
        whitelistSignerPrivateKey = 0xD0D;

        //生成地址
        owner = vm.addr(ownerPrivateKey);
        user1 = vm.addr(user1PrivateKey);
        user2 = vm.addr(user2PrivateKey);
        whitelistSigner = vm.addr(whitelistSignerPrivateKey);

        //部署合约
        vm.startPrank(owner);
        token = new MyToken("MyEIP721Token", "MET");
        nft = new MyERC721("MyEIP721NFT", "MENFT");
        tokenBank = new TokenBank(address(token));
        nftMarket = new NFTMarket(
            address(token),
            address(nft),
            whitelistSigner
        );
        vm.stopPrank();

        //给用户分配一些token
        vm.startPrank(owner);
        token.transfer(user1, 100 * 1e18);
        token.transfer(user2, 100 * 1e18);


        //铸造NFT
        nft.mint(owner, "ipfs://QmToken1");
        nft.mint(owner, "ipfs://QmToken2");
        vm.stopPrank();
    }

    //测试Permit存款
    function testPermitDeposit() public {
        uint256 amount = 10 * 1e18;
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = token.nonces(user1);

        //EIP-2612 是 ERC20 的扩展，它使用了 EIP-712 签名结构，因此也必须有一个 DOMAIN_SEPARATOR
        bytes32 domainSeparator = token.DOMAIN_SEPARATOR();
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256(
                    "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
                ),
                user1,
                address(tokenBank),
                amount,
                nonce,
                deadline
            )
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(user1PrivateKey, digest);
        
        //记录初始余额
        uint256 initBalance = tokenBank.balances(user1);
        uint256 initTokenBalance = token.balanceOf(user1);

        //执行permitDeposit
        vm.prank(user1);
        tokenBank.permitDeposit(amount, deadline, v, r, s);

        //验证
        assertEq(tokenBank.balances(user1), initBalance + amount, "Bank balance should increase");
        assertEq(token.balanceOf(user1), initTokenBalance - amount, "User token balance should decrease");
        assertEq(token.balanceOf(address(tokenBank)), amount, "TokenBank should receive tokens");
    }

    
    //测试Permit购买NFT
    function testPermitBuyNFT() public {
        uint256 tokenId = 1; // NFT ID从1开始，因为使用了Counters
        uint256 price = 5 * 1e18;
        uint256 deadline = block.timestamp + 1 hours;

        vm.prank(owner);
        nft.approve(address(nftMarket), tokenId);
    
        vm.prank(owner);
        nftMarket.list(tokenId, price);

        ////创建白名单签名
        //构造签名的消息内容，并进行哈希。 EIP-712 签名结构
        bytes32 messageHash = keccak256(abi.encodePacked(
            user1, tokenId, price, deadline
        ));
        
        //对消息进一步加工。使其变成以太坊签名标准格式:keccak256("\x19Ethereum Signed Message:\n32" + messageHash)
        //这样做的目的是防止签名重放攻击（防止将普通数据签名伪装成交易等重要消息）。
        //合约中用 ecrecover(ethSignedMessageHash, v, r, s) 验证时也要用这个哈希。
        bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash();
        
        //私钥签名
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(whitelistSignerPrivateKey, ethSignedMessageHash);
        //拼接签名（最终的签名）
        bytes memory signature = abi.encodePacked(r, s, v);

        //记录初始状态
        //address initOwner = nft.ownerOf(tokenId);
        uint256 initUserBalance = token.balanceOf(user1);
        
        // 用户需要先授权Token给NFTMarket
        vm.prank(user1);
        token.approve(address(nftMarket), price);
        
        //购买
        vm.prank(user1);
        nftMarket.permitBuy(tokenId, price, deadline, signature);

        //验证
        assertEq(nft.ownerOf(tokenId), user1, "NFT should be transferred to user1");
        assertEq(token.balanceOf(user1), initUserBalance - price, "User token balance should decrease");
        assertEq(token.balanceOf(address(nftMarket)), price, "NFTMarket should receive tokens");
    }


    //购买失败，不在白名单
    function test_RevertWhen_NotInWhitelist() public {
        uint256 tokenId = 1;
        uint256 price = 5 * 1e18;

        vm.prank(owner);
        nft.approve(address(nftMarket), tokenId);

        vm.prank(owner);
        nftMarket.list(tokenId, price);

        //创建签名
        uint256 deadline = block.timestamp + 1 hours;
        bytes32 messageHash = keccak256(abi.encodePacked(
            user1, tokenId, price, deadline
        ));
        bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash();
        
        //本应该用owner的私钥签名的
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(user1PrivateKey, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        //应该失败
        vm.prank(user1);
        vm.expectRevert(NFTMarket.InvalidSignature.selector);
        nftMarket.permitBuy(tokenId, price, deadline, signature);
    }

    //购买失败，签名过期
    function test_RevertWhen_SignatureExpired() public {
        uint256 tokenId = 1;
        uint256 price = 5 * 1e18;

        //一小时之前过期
        uint256 deadline = block.timestamp - 1;

        vm.prank(owner);
        nft.approve(address(nftMarket), tokenId);

        vm.prank(owner);
        nftMarket.list(tokenId, price);

        //签名
        bytes32 messageHash = keccak256(abi.encodePacked(
            user1, tokenId, price, deadline
        ));
        bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(whitelistSignerPrivateKey, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        
        vm.prank(user1);
        vm.expectRevert("Signature expired");
        nftMarket.permitBuy(tokenId, price, deadline, signature);
    }

    //购买失败，重复签名
    function test_RevertWhen_SignatureReused() public {
        uint256 tokenId = 1;
        uint256 price = 5 * 1e18;
        uint256 deadline = block.timestamp + 1 hours;

        // 初始上架
        vm.prank(owner);
        nft.approve(address(nftMarket), tokenId);
        vm.prank(owner);
        nftMarket.list(tokenId, price);

        // 为user1创建签名
        bytes32 messageHash = keccak256(abi.encodePacked(
            user1, tokenId, price, deadline
        ));
        bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(whitelistSignerPrivateKey, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // user1购买
        vm.prank(user1);
        token.approve(address(nftMarket), price);
        vm.prank(user1);
        nftMarket.permitBuy(tokenId, price, deadline, signature);

        // user1上架
        vm.prank(user1);
        nft.approve(address(nftMarket), tokenId);
        vm.prank(user1);
        nftMarket.list(tokenId, price);

        // 为user2创建签名
        messageHash = keccak256(abi.encodePacked(
            user2, tokenId, price, deadline
        ));
        ethSignedMessageHash = messageHash.toEthSignedMessageHash();
        (v, r, s) = vm.sign(whitelistSignerPrivateKey, ethSignedMessageHash);
        bytes memory signature2 = abi.encodePacked(r, s, v);

        // user2购买
        vm.prank(user2);
        token.approve(address(nftMarket), price);
        vm.prank(user2);
        nftMarket.permitBuy(tokenId, price, deadline, signature2);

        // user2上架
        vm.prank(user2);
        nft.approve(address(nftMarket), tokenId);
        vm.prank(user2);
        nftMarket.list(tokenId, price);

        // user1使用已使用的签名购买，应该失败
        vm.prank(user1);
        token.approve(address(nftMarket), price);
        vm.prank(user1);
        vm.expectRevert(NFTMarket.SignatureAlreadyUsed.selector);
        nftMarket.permitBuy(tokenId, price, deadline, signature);
    }
}

