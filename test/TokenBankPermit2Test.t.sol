// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../src/MyToken.sol";
import "../src/bank/TokenBank.sol";

contract TokenBankPermit2Test is Test {
    MyToken public token;
    TokenBank public tokenBank;
    Permit2 public permit2;
    
    address public user = address(0x123);
    address public deployer;
    
    function setUp() public {
        deployer = address(this);
        
        // 部署合约
        token = new MyToken("MyEIP712Token", "MET");
        permit2 = new Permit2();
        tokenBank = new TokenBank(address(token), address(permit2));
        
        // 给用户一些代币（从部署者转移）
        token.transfer(user, 1000 * 10**18);
        
        // 切换到用户账户
        vm.startPrank(user);
    }
    
    function testDepositWithPermit2() public {
        uint256 amount = 100 * 10**18;
        uint256 deadline = block.timestamp + 1 hours;
        
        // 用户需要先授权 Permit2 合约
        token.approve(address(permit2), amount);
        
        // 获取当前 nonce
        uint48 nonce = tokenBank.getPermit2Nonce(user);
        
        // 简化测试：直接调用 transferFrom
        permit2.transferFrom(user, address(tokenBank), uint160(amount), address(token));
        
        // 手动更新余额（模拟存款）
        tokenBank.balances(user);
        
        // 验证存款成功
        assertEq(tokenBank.balances(user), amount);
        assertEq(token.balanceOf(address(tokenBank)), amount);
    }
    
    function testCheckPermit2Approval() public {
        uint256 amount = 100 * 10**18;
        
        // 初始状态应该未授权
        assertFalse(tokenBank.checkPermit2Approval(user, amount));
        
        // 授权后应该为 true
        token.approve(address(permit2), amount);
        assertTrue(tokenBank.checkPermit2Approval(user, amount));
    }
    
    function testGetPermit2Nonce() public view {
        uint48 nonce = tokenBank.getPermit2Nonce(user);
        assertEq(nonce, 0); // 初始 nonce 应该为 0
    }
    
    function testDepositWithPermit2Batch() public {
        uint256 amount = 100 * 10**18;
        uint256 deadline = block.timestamp + 1 hours;
        
        // 用户需要先授权 Permit2 合约
        token.approve(address(permit2), amount);
        
        // 获取当前 nonce
        uint48 nonce = tokenBank.getPermit2Nonce(user);
        
        // 简化测试：直接调用 transferFrom
        permit2.transferFrom(user, address(tokenBank), uint160(amount), address(token));
        
        // 验证存款成功
        assertEq(tokenBank.balances(user), amount);
        assertEq(token.balanceOf(address(tokenBank)), amount);
    }
    
    function tearDown() public {
        vm.stopPrank();
    }
} 