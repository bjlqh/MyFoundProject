// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * 这些函数处理不同长度的字节数组的哈希值，并返回标准的32字节哈希值
 */
library MerkleProof {

    /**
     * 返回通过将叶子节点与证明中的元素进行哈希计算得出的根哈希值，
     * 如果证明有效，则返回的根哈希值应该与树的根哈希值匹配。
     */
    function verify(
        bytes32[] memory proof,
        bytes32 root,
        bytes32 leaf
    ) internal pure returns (bool) {
        return processProof(proof, leaf) == root;
    }

    /**
     * 返回通过处理证明重建的根哈希值。
     * 叶子节点和证明元素应该按照正确的顺序提供。
     * @param proof 证明数组
     * @param leaf 叶子节点
     */
    function processProof(
        bytes32[] memory proof,
        bytes32 leaf
    ) internal pure returns (bytes32) {
        bytes32 computedHash = leaf;
        for (uint i = 0; i < proof.length; i++) {
            computedHash = _hashPair(computedHash, proof[i]);
        }
        return computedHash;
    }

    /**
     * 返回两个排序的哈希值的哈希
     */
    function _hashPair(bytes32 a, bytes32 b) private pure returns (bytes32) {
        return a < b ? _efficientHash(a, b) : _efficientHash(b, a);
    }

    /**
     * 返回两个排序的哈希值的哈希值，使用更少的gas
     */
    function _efficientHash(bytes32 a, bytes32 b) private pure returns (bytes32 value) {
        //keccak256(abi.encodePacked(a, b))
        assembly {
            mstore(0x00, a)
            mstore(0x20, b)
            value := keccak256(0x00, 0x40)
        }
    }
}
