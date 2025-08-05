// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/MyToken.sol";
import "../src/MyERC721.sol";
import "../src/multicall/MerkleTree.sol";
import "../src/multicall/AirdropMerkleNFTMarket.sol";

contract DeployAirdropMerkleNFTMarketScript is Script {
    function run() external {
        uint deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        MyToken token = new MyToken("MyToken", "MT");
        console.log("Token deployed at:", address(token));

        MyERC721 nft = new MyERC721("MyNFT", "MNFT");
        console.log("NFT deployed at:", address(nft));

        //merkle树根
        bytes32 merkleRoot = buildMerkleTree();

        AirdropMerkleNFTMarket market = new AirdropMerkleNFTMarket(
            address(token),
            address(nft),
            merkleRoot
        );
        console.log("NFTMarket deployed at:", address(market));

        vm.stopBroadcast();
    }

    function buildMerkleTree() internal returns (bytes32) {
        MerkleTree merkleTree = new MerkleTree();
        //构建白名单和merkle树
        address[] memory whitelist = new address[](3);
        whitelist[0] = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
        whitelist[1] = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
        whitelist[2] = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
        whitelist[3] = 0x90F79bf6EB2c4f870365E785982E1f101E93b906;
        whitelist[4] = 0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65;

        uint[] memory tokenIds = new uint[](3);
        tokenIds[0] = 1;
        tokenIds[1] = 2;
        tokenIds[2] = 3;
        tokenIds[3] = 4;
        tokenIds[4] = 5;

        bytes32[] memory leaves = merkleTree.getLeaves(whitelist, tokenIds);
        bytes32 root = merkleTree.getRoot(leaves);
        console.log(unicode"叶子节点数量:", leaves.length);
        //为每个用户生成证明
        for (uint i = 0; i < whitelist.length; i++) {
            bytes32[] memory proof = merkleTree.getProof(leaves, i);
            //生成当前节点的hash
            bytes32 leafHash = merkleTree.getLeafHash(
                whitelist[i],
                tokenIds[i]
            );

            console.log(unicode"用户", i + 1, ":", whitelist[i]);
            console.log("Token ID:", tokenIds[i]);
            console.log(unicode"叶子节点:", vm.toString(leafHash));
            console.log(unicode"证明长度:", proof.length);
            console.log(unicode"证明:");
            for(uint j = 0; j < proof.length; j++){
                console.log("[",j,"]:", vm.toString(proof[j]));
            }

            //验证证明
            bool isValid = merkleTree.verifyProof(proof, root, leafHash);
            console.log(unicode"验证结果:", isValid);
            console.log("------------------------");
        }

        console.log(unicode"\n========= 部署信息 =========");
        console.log(unicode"MerkleTree 合约地址:", address(merkleTree));
        console.log(unicode"Merkle 根哈希:", vm.toString(root));
        return root;
    }
}
