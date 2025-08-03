// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/console.sol";
import "forge-std/Test.sol";
import "../src/MyToken.sol";
import "../src/MyERC721.sol";
import "../src/multicall/AirdropMerkleNFTMarket.sol";
import "../src/multicall/AirdropMerkleNFTMarketMulticall.sol";
import "../src/multicall/MerkleTree.sol";
import "../src/multicall/MerkleProof.sol";

contract AirdropMerkleNFTMerkleTest is Test {
    MyToken public token;
    MyERC721 public nft;
    AirdropMerkleNFTMarket public market;
    AirdropMerkleNFTMarketMulticall public marketMulticall;
    MerkleTree public merkleTree;

    address public owner = address(this);
    uint256 public privateKey1 = 0xA11CE;
    uint256 public privateKey2 = 0xB0B;
    uint256 public privateKey3 = 0xC0DE;
    address public user1 = vm.addr(privateKey1);
    address public user2 = vm.addr(privateKey2);
    address public user3 = vm.addr(privateKey3);
    uint public user1Balance = 100 * 1e18;
    uint public user2Balance = 100 * 1e18;
    uint public user3Balance = 100 * 1e18;

    bytes32 public merkleRoot;

    function setUp() public {
        //部署合约
        token = new MyToken("TestToken", "TTK");
        nft = new MyERC721("TestNFT", "TNFT");
        merkleTree = new MerkleTree();

        // 设置测试用的 Merkle 根
        merkleRoot = 0x1234567890123456789012345678901234567890123456789012345678901234;

        market = new AirdropMerkleNFTMarket(
            address(token),
            address(nft),
            merkleRoot
        );
        marketMulticall = new AirdropMerkleNFTMarketMulticall(
            address(token),
            address(nft),
            merkleRoot
        );

        //给用户分配token
        token.transfer(user1, user1Balance);
        token.transfer(user2, user1Balance);
        token.transfer(user3, user1Balance);

        //铸造nft
        nft.mint(user1, "tokenURI1");
        nft.mint(user2, "tokenURI2");
        nft.mint(user3, "tokenURI3");
    }

    //验证merkle树
    function testMerkleTreeOperation() public view {
        address user4 = address(0x4);
        address user5 = address(0x5);
        address user6 = address(0x6);
        address user7 = address(0x7);
        address user8 = address(0x8);
        address[] memory whitelist = new address[](8);
        whitelist[0] = user1;
        whitelist[1] = user2;
        whitelist[2] = user3;
        whitelist[3] = user4;
        whitelist[4] = user5;
        whitelist[5] = user6;
        whitelist[6] = user7;
        whitelist[7] = user8;

        uint[] memory tokenIds = new uint[](8);
        tokenIds[0] = 1;
        tokenIds[1] = 2;
        tokenIds[2] = 3;
        tokenIds[3] = 4;
        tokenIds[4] = 5;
        tokenIds[5] = 6;
        tokenIds[6] = 7;
        tokenIds[7] = 8;

        //获取所有叶子节点
        bytes32[] memory leaves = merkleTree.getLeaves(whitelist, tokenIds);
        console.log("leaves array:");
        for (uint i = 0; i < leaves.length; i++) {
            console.log("leaves[", i, "]:", uint256(leaves[i]));
        }
        console.log("leaves.length:", leaves.length);

        //计算根
        bytes32 root = merkleTree.getRoot(leaves);
        console.log("root:", uint256(root));
        assertTrue(root != bytes32(0));

        //生成证明路径
        bytes32[] memory proof = merkleTree.getProof(leaves, 0);
        console.log("proof array:");
        for (uint i = 0; i < proof.length; i++) {
            console.log("proof[", i, "]:", uint256(proof[i]));
        }
        console.log("proof.length:", proof.length);

        //验证证明
        bytes32 leaf = merkleTree.getLeafHash(user1, tokenIds[0]);
        console.log("leaf:", uint256(leaf));
        bool isValid = merkleTree.verifyProof(proof, root, leaf);
        console.log("isValid:", isValid);
        assertTrue(isValid);
    }

    //使用merkle树验证白名单用户
    function testWhitelist() public view {
        // 构建白名单
        address[] memory whitelist = new address[](3);
        whitelist[0] = user1;
        whitelist[1] = user2;
        whitelist[2] = user3;

        uint[] memory tokenIds = new uint[](3);
        tokenIds[0] = 1;
        tokenIds[1] = 2;
        tokenIds[2] = 3;

        //生成merkle树
        bytes32[] memory leaves = merkleTree.getLeaves(whitelist, tokenIds);
        bytes32 root = merkleTree.getRoot(leaves);

        //为user1生成proof
        bytes32[] memory proof1 = merkleTree.getProof(leaves, 0);
        //验证user1在白名单中
        bytes32 leaf1 = merkleTree.getLeafHash(user1, tokenIds[0]);
        bool isValid1 = merkleTree.verifyProof(proof1, root, leaf1);
        assertTrue(isValid1, "user1 should be in whitelist");

        //验证user4不在白名单中
        bytes32[] memory proof4 = merkleTree.getProof(leaves, 0);
        //验证user1在白名单中
        address user4 = address(0x4);
        bytes32 leaf4 = merkleTree.getLeafHash(user4, tokenIds[0]);
        bool isValid4 = merkleTree.verifyProof(proof4, root, leaf4);
        assertFalse(isValid4, "user4 should not be in whitelist!");
    }

    //白名单用户可以以优惠价格购买nft
    function testPermitAndClaimNFTForWhitelist() public {
        vm.startPrank(user1);
        uint tokenId = 1;
        uint price = 10 * 1e18;
        nft.approve(address(marketMulticall), tokenId);
        marketMulticall.list(tokenId, price);
        vm.stopPrank();

        //构建白名单
        address[] memory whitelist = new address[](3);
        whitelist[0] = user1;
        whitelist[1] = user2;
        whitelist[2] = user3;

        uint[] memory tokenIds = new uint[](3);
        tokenIds[0] = 1;
        tokenIds[1] = 1;
        tokenIds[2] = 1;

        //生成merkle树并更新市场
        bytes32[] memory leaves = merkleTree.getLeaves(whitelist, tokenIds);
        bytes32 root = merkleTree.getRoot(leaves);
        market.updateMerkleRoot(root);
        marketMulticall.updateMerkleRoot(root);

        //为user2生成proof,user2在白名单中
        bytes32[] memory proof = merkleTree.getProof(leaves, 1); //user2对应的索引是1

        //打印验证信息
        bytes32 leaf = merkleTree.getLeafHash(user2, tokenId);
        for (uint i = 0; i < proof.length; i++) {
            console.log("Test - Proof", i, ":", uint256(proof[i]));
        }
        bool isValid = merkleTree.verifyProof(proof, root, leaf);
        console.log("Test - Proof valid:", isValid);

        vm.startPrank(user2);
        uint deadline = block.timestamp + 1 hours;
        //优惠价格
        uint discountPrice = 5 * 1e18;
        uint proofValue;        //授权金额
        if(isValid){
            proofValue = discountPrice;
        }else {
            proofValue = price;
        }

        //生成签名
        bytes32 PERMIT_TYPEHASH = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
        bytes32 separator = token.DOMAIN_SEPARATOR();
        bytes32 structHash = keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                user2,
                address(marketMulticall),
                proofValue,
                token.nonces(user2),
                deadline
            )
        );
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", separator, structHash)
        );
        //user2想让market转移其代币，那么就需要user2自己的私钥进行签名
        //market调用token.permit,MyToken合约内部使用ecrecover恢复签名者地址
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey2, digest);     

        marketMulticall.permitAndClaimNFT(
            tokenId,
            proof,
            user2,
            address(marketMulticall),
            proofValue,
            deadline,
            v,
            r,
            s
        );

        //验证user2购买成功
        assertEq(nft.ownerOf(tokenId), user2);
        //验证user2支付成功
        assertEq(
            token.balanceOf(user2),
            user2Balance - (price - discountPrice)
        );
        assertEq(token.balanceOf(address(marketMulticall)), discountPrice);
        vm.stopPrank();
    }

    //非白名单用户不可以以优惠价格购买nft
    function testPermitAndClaimNFTForNonWhitelist() public {
        vm.startPrank(user1);
        uint tokenId = 1;
        uint price = 10 * 1e18;
        nft.approve(address(marketMulticall), tokenId);
        marketMulticall.list(tokenId, price);
        vm.stopPrank();

        //构建白名单
        address[] memory whitelist = new address[](3);
        whitelist[0] = user1;
        whitelist[1] = user2;
        whitelist[2] = user3;

        uint[] memory tokenIds = new uint[](3);
        tokenIds[0] = 1;
        tokenIds[1] = 1;
        tokenIds[2] = 2; // 用户3的tokenId不在白名单范围

        //生成merkle树并更新市场
        bytes32[] memory leaves = merkleTree.getLeaves(whitelist, tokenIds);
        bytes32 root = merkleTree.getRoot(leaves);
        market.updateMerkleRoot(root);
        marketMulticall.updateMerkleRoot(root);

        //为user3生成proof,user3不在白名单中
        bytes32[] memory proof = merkleTree.getProof(leaves, 2); //user3对应的索引是2

        //打印验证信息
        bytes32 leaf = merkleTree.getLeafHash(user3, tokenId);
        for (uint i = 0; i < proof.length; i++) {
            console.log("Test - Proof", i, ":", uint256(proof[i]));
        }
        bool isValid = merkleTree.verifyProof(proof, root, leaf);
        console.log("Test - Proof valid:", isValid);

        vm.startPrank(user3);
        // 确保所有签名参数与链状态同步
        vm.warp(block.timestamp + 1);
        uint256 nonce = token.nonces(user3);
        uint256 deadline = block.timestamp + 3600;
        //优惠价格
        uint discountPrice = 5 * 1e18;

        uint proofValue;        //授权金额
        if(isValid){
            proofValue = discountPrice;
        }else {
            proofValue = price;
        }
        //生成签名
        bytes32 PERMIT_TYPEHASH = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
        bytes32 separator = token.DOMAIN_SEPARATOR();
        bytes32 structHash = keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                user3,
                address(marketMulticall),
                proofValue,
                nonce,
                deadline
            )
        );
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", separator, structHash)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey3, digest);

        marketMulticall.permitAndClaimNFT(
            tokenId,
            proof,
            user3,
            address(marketMulticall),
            proofValue,
            deadline,
            v,
            r,
            s
        );

        //验证user3购买成功
        assertEq(nft.ownerOf(tokenId), user3);
        //验证user3支付成功（非白名单用户按原价购买）
        assertEq(token.balanceOf(user3), user3Balance - price);
        assertEq(token.balanceOf(address(marketMulticall)), price);
        vm.stopPrank();
    }
}
