// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * 提供批量调用合约功能
 */
contract Multicall {
    
    struct Call {
        address target;
        bytes callData;
    }

    struct Result {
        bool success;
        bytes returnData;
    }

    /**
     * 批量执行调用，失败时就回滚
     * @param calls 要执行的调用数组
     * @return blockNumber 执行调用的区块号
     * @return returnData 调用结果数组
     */
    function aggregate(
        Call[] memory calls
    ) public returns (uint blockNumber, bytes[] memory returnData) {
        blockNumber = block.number;
        returnData = new bytes[](calls.length);
        for (uint i = 0; i < calls.length; i++) {
            (bool success, bytes memory ret) = calls[i].target.call(
                calls[i].callData
            );
            require(success, "Multicall: call failed");
            returnData[i] = ret;
        }
    }

    /**
     * 批量执行调用，允许失败
     * @param requireSuccess 要执行的调用函数
     * @param calls 调用结果数组
     */
    function tryAggregate(
        bool requireSuccess,
        Call[] memory calls
    ) public returns (Result[] memory results) {
        results = new Result[](calls.length);
        for (uint i = 0; i < calls.length; i++) {
            (bool success, bytes memory ret) = calls[i].target.call(
                calls[i].callData
            );
            if (requireSuccess) {
                require(success, "Multicall: call failed");
            }
            results[i] = Result(success, ret);
        }
    }

    /**
     * 使用delegatecall 执行调用
     * @param calls 要执行的调用数组
     * @return blockNumber 执行调用的区块号
     * @return returnData 调用结果数组
     */
    function aggregateWithDelegateCall(
        Call[] memory calls
    ) public returns (uint blockNumber, bytes[] memory returnData) {
        blockNumber = block.number;
        returnData = new bytes[](calls.length);
        for(uint i = 0; i < calls.length; i++){
            (bool success, bytes memory ret) = calls[i].target.delegatecall(calls[i].callData);
            require(success, "Multicall: aggregateWithDelegateCall failded");
            returnData[i] = ret;
        }
    }
}
