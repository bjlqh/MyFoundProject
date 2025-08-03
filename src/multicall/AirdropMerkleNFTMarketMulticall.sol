// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./AirdropMerkleNFTMarket.sol";
import "./Multicall.sol";

contract AirdropMerkleNFTMarketMulticall is AirdropMerkleNFTMarket, Multicall {
    constructor(
        address _token,
        address _nft,
        bytes32 _merkleRoot
    ) AirdropMerkleNFTMarket(_token, _nft, _merkleRoot) {}

    /**
     * 批量执行permit 和 claimNFT
     * @param tokenId nft id
     * @param proof merkle证明
     * @param owner 所有者
     * @param spender 授权者
     * @param value 授权金额
     * @param deadline 截止时间
     * @param v permit签名参数
     * @param r 签名参数
     * @param s 签名参数
     */
    function permitAndClaimNFT(
        uint tokenId,
        bytes32[] memory proof,
        address owner,
        address spender,
        uint value,
        uint deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        //创建调用数组
        Call[] memory calls = new Call[](2);

        //第一个调用permitPrePay
        calls[0] = Call({
            target: address(this),
            callData: abi.encodeWithSelector(
                this.permitPerPay.selector,
                owner,
                spender,
                value,
                deadline,
                v,
                r,
                s
            )
        });

        //第二个调用: claimNTF
        calls[1] = Call({
            target: address(this),
            callData: abi.encodeWithSelector(
                this.claimNFT.selector,
                tokenId,
                proof
            )
        });

        //使用delegatecall 批量执行
        aggregateWithDelegateCall(calls);
    }
}
