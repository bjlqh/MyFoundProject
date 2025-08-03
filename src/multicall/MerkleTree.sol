// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./MerkleProof.sol";

/**
 * Merkle树构建和验证工具
 */
contract MerkleTree {
    using MerkleProof for bytes32[];

    /**
     * 计算叶子节点的哈希值
     * @param account 用户地址
     * @param tokenId nft id
     * @return 叶子节点的哈希值
     */
    function getLeafHash(
        address account,
        uint tokenId
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(account, tokenId));
    }

    /**
     * 计算多个叶子节点的哈希值
     * @param accounts 用户地址数组
     * @param tokenIds nft id数组
     * @return 叶子节点哈希值数组
     */
    function getLeaves(
        address[] memory accounts,
        uint[] memory tokenIds
    ) public pure returns (bytes32[] memory) {
        require(accounts.length == tokenIds.length, "Arrays length mismatch");

        bytes32[] memory leaves = new bytes32[](accounts.length);
        for (uint i = 0; i < accounts.length; i++) {
            leaves[i] = getLeafHash(accounts[i], tokenIds[i]);
        }
        return leaves;
    }

    /**
     * 计算merkle根
     * @param leaves 叶子节点的数组
     * @return Merkle根
     */
    function getRoot(bytes32[] memory leaves) public pure returns (bytes32) {
        require(leaves.length > 0, "Empty leaves array");

        if (leaves.length == 1) {
            return leaves[0];
        }

        bytes32[] memory arr = leaves;
        while (arr.length > 1) {
            //叶子节点的父节点一层
            bytes32[] memory nextLevel = new bytes32[](
                (arr.length + 1) / 2
            );

            for (uint i = 0; i < arr.length; i += 2) {
                if (i + 1 < arr.length) {
                    nextLevel[i / 2] = _hashPair(arr[i], arr[i + 1]);
                } else {
                    //只有一个元素
                    nextLevel[i / 2] = arr[i];
                }
            }

            //向上递进
            arr = nextLevel;
        }
        return arr[0];
    }

    /**
     * 生成merkle 证明节点数组
     * @param leaves 叶子节点数组
     * @param leafIndex 目标叶子节点索引
     * @return 证明数组
     */
    function getProof(
        bytes32[] memory leaves,
        uint leafIndex
    ) public pure returns (bytes32[] memory) {
        require(leafIndex < leaves.length, "Leaf index out of bounds");
        
        bytes32[] memory proof = new bytes32[](0);
        bytes32[] memory arr = leaves;
        uint curIndex = leafIndex;

        while (arr.length > 1) {
            // 添加兄弟节点到证明中
            if (curIndex % 2 == 0) {
                if (curIndex + 1 < arr.length) {
                    proof = _appendToArray(proof, arr[curIndex + 1]);
                }
            } else {
                proof = _appendToArray(proof, arr[curIndex - 1]);
            }

            // 计算下一层
            bytes32[] memory nextLevel = new bytes32[]((arr.length + 1) / 2);
            for (uint i = 0; i < arr.length; i += 2) {
                if (i + 1 < arr.length) {
                    nextLevel[i / 2] = _hashPair(arr[i], arr[i + 1]);
                } else {
                    nextLevel[i / 2] = arr[i];
                }
            }

            arr = nextLevel;
            curIndex = curIndex / 2;
        }
        return proof;
    }

    function verifyProof(
        bytes32[] memory proof,
        bytes32 root,
        bytes32 leaf
    ) public pure returns (bool) {
        return proof.verify(root, leaf);
    }

    /**
     * 向数组追加元素
     * @param array 数组
     * @param element 要追加的元素
     */
    function _appendToArray(
        bytes32[] memory array,
        bytes32 element
    ) private pure returns (bytes32[] memory) {
        bytes32[] memory newArray = new bytes32[](array.length + 1);
        for (uint i = 0; i < array.length; i++) {
            newArray[i] = array[i];
        }

        newArray[array.length] = element;
        return newArray;
    }

    function _hashPair(bytes32 a, bytes32 b) private pure returns (bytes32) {
        return a < b ? _efficientHash(a, b) : _efficientHash(b, a);
    }

    function _efficientHash(
        bytes32 a,
        bytes32 b
    ) private pure returns (bytes32 value) {
        assembly {
            mstore(0x00, a)
            mstore(0x20, b)
            value := keccak256(0x00, 0x40)
        }
    }
}
