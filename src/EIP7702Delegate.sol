// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./bank/TokenBank.sol";
import {Permit2} from "@permit2/Permit2.sol";
import {IAllowanceTransfer} from "@permit2/interfaces/IAllowanceTransfer.sol";

/**
 * @title EIP7702Delegate
 * @dev EIP-7702 委托合约，支持批量执行操作
 * 允许EOA账户委托给此合约，实现账户抽象功能
 */
contract EIP7702Delegate {
    
    // 事件定义
    event BatchExecuted(address indexed executor, uint256 operationCount);
    event TokenApproved(address indexed token, address indexed spender, uint256 amount);
    event TokenBankDeposit(address indexed bank, uint256 amount);
    
    // 错误定义
    error InvalidOperation();
    error ExecutionFailed(uint256 index, bytes reason);
    error UnauthorizedCaller();
    
    // 操作类型枚举
    enum OperationType {
        APPROVE_TOKEN,      // 授权代币
        DEPOSIT_TO_BANK,    // 存款到银行
        PERMIT2_APPROVE,    // Permit2授权
        PERMIT2_DEPOSIT     // Permit2存款
    }
    
    // 操作结构体
    struct Operation {
        OperationType opType;
        address target;     // 目标合约地址
        uint256 amount;     // 金额
        bytes data;         // 额外数据
    }
    
    // 批量操作结构体
    struct BatchOperation {
        Operation[] operations;
        uint256 deadline;   // 截止时间
    }
    
    /**
     * @dev 执行单个操作
     * @param op 要执行的操作
     */
    function executeOperation(Operation calldata op) external {
        try this._executeOperation(op) {
            // 操作成功执行
        } catch (bytes memory reason) {
            revert ExecutionFailed(0, reason);
        }
    }
    
    /**
     * @dev 批量执行操作
     * @param batchOp 批量操作结构体
     */
    function executeBatch(BatchOperation calldata batchOp) external {
        require(block.timestamp <= batchOp.deadline, "Batch operation expired");
        
        uint256 operationCount = batchOp.operations.length;
        require(operationCount > 0, "No operations to execute");
        
        for (uint256 i = 0; i < operationCount; i++) {
            try this._executeOperation(batchOp.operations[i]) {
                // 操作成功
            } catch (bytes memory reason) {
                revert ExecutionFailed(i, reason);
            }
        }
        
        emit BatchExecuted(msg.sender, operationCount);
    }
    
    /**
     * @dev 授权并存款的组合操作
     * @param token 代币地址
     * @param bank 银行合约地址
     * @param amount 金额
     */
    function approveAndDeposit(
        address token,
        address bank,
        uint256 amount
    ) external {
        // 1. 授权代币给银行合约
        IERC20(token).approve(bank, amount);
        emit TokenApproved(token, bank, amount);
        
        // 2. 调用银行合约存款
        TokenBank(bank).deposit(amount);
        emit TokenBankDeposit(bank, amount);
    }
    
    /**
     * @dev 使用Permit2进行授权并存款
     * @param token 代币地址
     * @param bank 银行合约地址
     * @param permit2 Permit2合约地址
     * @param amount 金额
     */
    function permit2ApproveAndDeposit(
        address token,
        address bank,
        address permit2,
        uint256 amount
    ) external {
        // 1. 授权代币给Permit2
        IERC20(token).approve(permit2, amount);
        emit TokenApproved(token, permit2, amount);
        
        // 2. 调用银行合约的普通存款方法
        // 注意：这里假设银行合约已经配置了Permit2
        TokenBank(bank).deposit(amount);
        emit TokenBankDeposit(bank, amount);
    }
    
    /**
     * @dev 内部执行操作函数
     * @param op 要执行的操作
     */
    function _executeOperation(Operation calldata op) external {
        require(msg.sender == address(this), "Only self-call allowed");
        
        if (op.opType == OperationType.APPROVE_TOKEN) {
            _approveToken(op.target, op.amount, op.data);
        } else if (op.opType == OperationType.DEPOSIT_TO_BANK) {
            _depositToBank(op.target, op.amount);
        } else if (op.opType == OperationType.PERMIT2_APPROVE) {
            _permit2Approve(op.target, op.amount, op.data);
        } else if (op.opType == OperationType.PERMIT2_DEPOSIT) {
            _permit2Deposit(op.target, op.amount, op.data);
        } else {
            revert InvalidOperation();
        }
    }
    
    /**
     * @dev 授权代币
     */
    function _approveToken(address target, uint256 amount, bytes calldata data) internal {
        address spender = abi.decode(data, (address));
        IERC20(target).approve(spender, amount);
        emit TokenApproved(target, spender, amount);
    }
    
    /**
     * @dev 存款到银行
     */
    function _depositToBank(address target, uint256 amount) internal {
        TokenBank(target).deposit(amount);
        emit TokenBankDeposit(target, amount);
    }
    
    /**
     * @dev Permit2授权
     */
    function _permit2Approve(address target, uint256 amount, bytes calldata data) internal {
        address permit2Address = abi.decode(data, (address));
        IERC20(target).approve(permit2Address, amount);
        emit TokenApproved(target, permit2Address, amount);
    }
    
    /**
     * @dev 使用Permit2存款
     */
    function _permit2Deposit(address target, uint256 amount, bytes calldata data) internal {
        // 这里可以实现更复杂的Permit2存款逻辑
        TokenBank(target).deposit(amount);
        emit TokenBankDeposit(target, amount);
    }
    
    /**
     * @dev 紧急情况下的代币恢复
     * @param token 代币地址
     * @param amount 金额
     */
    function emergencyWithdraw(address token, uint256 amount) external {
        // 只允许合约本身调用（通过委托）
        require(msg.sender == address(this), "Unauthorized");
        IERC20(token).transfer(tx.origin, amount);
    }
    
    /**
     * @dev 获取代币余额
     * @param token 代币地址
     * @return 余额
     */
    function getTokenBalance(address token) external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }
    
    /**
     * @dev 检查代币授权额度
     * @param token 代币地址
     * @param spender 被授权地址
     * @return 授权额度
     */
    function getAllowance(address token, address spender) external view returns (uint256) {
        return IERC20(token).allowance(address(this), spender);
    }
}