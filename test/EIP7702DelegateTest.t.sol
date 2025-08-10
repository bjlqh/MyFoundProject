// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/EIP7702Delegate.sol";
import "../src/MyToken.sol";
import "../src/bank/TokenBank.sol";
import {Permit2} from "@permit2/Permit2.sol";

contract EIP7702DelegateTest is Test {
    EIP7702Delegate public delegate;
    MyToken public token;
    TokenBank public bank;
    Permit2 public permit2;
    
    address public user = address(0x1);
    address public deployer = address(this);
    
    uint256 constant INITIAL_SUPPLY = 1000 * 10**18;
    uint256 constant TEST_AMOUNT = 50 * 10**18;
    
    function setUp() public {
        // 部署合约
        delegate = new EIP7702Delegate();
        token = new MyToken("Test Token", "TEST", 0);
        permit2 = new Permit2();
        bank = new TokenBank(address(token), address(permit2));
        
        // 给用户分配代币
        token.transfer(user, TEST_AMOUNT * 5);
        // 给delegate合约分配代币用于测试
        token.transfer(address(delegate), TEST_AMOUNT * 3);
        
        // 设置用户环境
        vm.startPrank(user);
        token.approve(address(delegate), type(uint256).max);
        vm.stopPrank();
        
        // 设置delegate合约的授权
        vm.startPrank(address(delegate));
        token.approve(address(bank), type(uint256).max);
        vm.stopPrank();
    }
    
    function testApproveAndDeposit() public {
        vm.startPrank(user);
        
        // 检查初始状态
        assertEq(token.balanceOf(user), TEST_AMOUNT * 5);
        assertEq(bank.balances(user), 0);
        
        // 先将代币转移给delegate合约
        token.transfer(address(delegate), TEST_AMOUNT);
        
        vm.stopPrank();
        
        // 使用delegate合约执行授权并存款
        vm.startPrank(address(delegate));
        delegate.approveAndDeposit(address(token), address(bank), TEST_AMOUNT);
        vm.stopPrank();
        
        // 检查结果 - 注意这里余额是delegate的，不是user的
        assertEq(bank.balances(address(delegate)), TEST_AMOUNT);
        assertEq(token.balanceOf(address(bank)), TEST_AMOUNT);
    }
    
    function testExecuteSingleOperation() public {
        vm.startPrank(user);
        
        // 创建授权操作
        EIP7702Delegate.Operation memory op = EIP7702Delegate.Operation({
            opType: EIP7702Delegate.OperationType.APPROVE_TOKEN,
            target: address(token),
            amount: TEST_AMOUNT,
            data: abi.encode(address(bank))
        });
        
        // 执行操作
        delegate.executeOperation(op);
        
        // 检查授权是否成功
        assertEq(token.allowance(address(delegate), address(bank)), TEST_AMOUNT);
        
        vm.stopPrank();
    }
    
    function testExecuteBatchOperations() public {
        vm.startPrank(user);
        
        // 先将代币转移给delegate合约
        token.transfer(address(delegate), TEST_AMOUNT);
        
        vm.stopPrank();
        
        // 使用delegate合约执行批量操作
        vm.startPrank(address(delegate));
        
        // 创建批量操作
        EIP7702Delegate.Operation[] memory operations = new EIP7702Delegate.Operation[](2);
        
        // 操作1: 授权代币
        operations[0] = EIP7702Delegate.Operation({
            opType: EIP7702Delegate.OperationType.APPROVE_TOKEN,
            target: address(token),
            amount: TEST_AMOUNT,
            data: abi.encode(address(bank))
        });
        
        // 操作2: 存款
        operations[1] = EIP7702Delegate.Operation({
            opType: EIP7702Delegate.OperationType.DEPOSIT_TO_BANK,
            target: address(bank),
            amount: TEST_AMOUNT,
            data: ""
        });
        
        EIP7702Delegate.BatchOperation memory batchOp = EIP7702Delegate.BatchOperation({
            operations: operations,
            deadline: block.timestamp + 1 hours
        });
        
        // 执行批量操作
        delegate.executeBatch(batchOp);
        
        // 检查结果
        assertEq(bank.balances(address(delegate)), TEST_AMOUNT);
        assertEq(token.balanceOf(address(bank)), TEST_AMOUNT);
        
        vm.stopPrank();
    }
    
    function testBatchOperationExpired() public {
        vm.startPrank(user);
        
        // 创建过期的批量操作
        EIP7702Delegate.Operation[] memory operations = new EIP7702Delegate.Operation[](1);
        operations[0] = EIP7702Delegate.Operation({
            opType: EIP7702Delegate.OperationType.APPROVE_TOKEN,
            target: address(token),
            amount: TEST_AMOUNT,
            data: abi.encode(address(bank))
        });
        
        EIP7702Delegate.BatchOperation memory batchOp = EIP7702Delegate.BatchOperation({
            operations: operations,
            deadline: block.timestamp - 1 // 过期时间
        });
        
        // 应该失败
        vm.expectRevert("Batch operation expired");
        delegate.executeBatch(batchOp);
        
        vm.stopPrank();
    }
    
    function testPermit2ApproveAndDeposit() public {
        vm.startPrank(user);
        
        // 先将代币转移给delegate合约
        token.transfer(address(delegate), TEST_AMOUNT);
        
        vm.stopPrank();
        
        // 使用delegate合约执行Permit2授权并存款
        vm.startPrank(address(delegate));
        delegate.permit2ApproveAndDeposit(
            address(token),
            address(bank),
            address(permit2),
            TEST_AMOUNT
        );
        
        // 检查存款
        assertEq(bank.balances(address(delegate)), TEST_AMOUNT);
        
        vm.stopPrank();
    }
    
    function testGetTokenBalance() public {
        // delegate合约在setUp中已经有代币了
        // 检查余额
        uint256 balance = delegate.getTokenBalance(address(token));
        assertEq(balance, TEST_AMOUNT * 3); // setUp中分配的数量
    }
    
    function testGetAllowance() public {
        vm.startPrank(user);
        
        // 先授权
        delegate.approveAndDeposit(address(token), address(bank), TEST_AMOUNT);
        
        // 检查授权额度
        uint256 allowance = delegate.getAllowance(address(token), address(bank));
        assertEq(allowance, 0); // 存款后授权应该被消耗
        
        vm.stopPrank();
    }
    
    function testEmergencyWithdraw() public {
        // 检查delegate合约的初始余额
        uint256 initialBalance = token.balanceOf(address(delegate));
        
        vm.startPrank(address(delegate));
        
        // 紧急提取
        delegate.emergencyWithdraw(address(token), TEST_AMOUNT);
        
        // 检查代币余额减少了
        assertEq(token.balanceOf(address(delegate)), initialBalance - TEST_AMOUNT);
        
        vm.stopPrank();
    }
    
    function testUnauthorizedEmergencyWithdraw() public {
        // 给delegate合约转一些代币
        token.transfer(address(delegate), TEST_AMOUNT);
        
        vm.startPrank(user);
        
        // 应该失败，因为不是合约本身调用
        vm.expectRevert("Unauthorized");
        delegate.emergencyWithdraw(address(token), TEST_AMOUNT);
        
        vm.stopPrank();
    }
    
    function testInvalidOperation() public {
        vm.startPrank(user);
        
        // 创建无效操作 - 使用不存在的操作类型组合
        EIP7702Delegate.Operation memory op = EIP7702Delegate.Operation({
            opType: EIP7702Delegate.OperationType.PERMIT2_DEPOSIT, // 使用有效类型但错误的参数
            target: address(0), // 无效地址
            amount: TEST_AMOUNT,
            data: ""
        });
        
        // 应该失败
        vm.expectRevert();
        delegate.executeOperation(op);
        
        vm.stopPrank();
    }
}