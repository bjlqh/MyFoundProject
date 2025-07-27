// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../src/MyToken.sol";
import "../src/bank/SimplePermit2.sol";

contract SimplePermit2Test is Test {
    MyToken public token;
    SimplePermit2 public permit2;
    
    address public user = address(0x123);
    address public spender = address(0x456);
    
    function setUp() public {
        // 部署合约
        token = new MyToken("MyEIP712Token", "MET");
        permit2 = new SimplePermit2();
        
        // 给用户一些代币（从部署者转移）
        token.transfer(user, 1000 * 10**18);
        
        // 用户授权 Permit2 合约
        vm.prank(user);
        token.approve(address(permit2), type(uint256).max);
    }
    
    function testPermit2Basic() public {
        uint256 amount = 100 * 10**18;
        
        // 用户授权 Permit2 合约
        vm.prank(user);
        token.approve(address(permit2), amount);
        
        // 使用 Permit2 转移代币
        permit2.transferFrom(user, spender, uint160(amount), address(token));
        
        // 验证转移成功
        assertEq(token.balanceOf(spender), amount);
        assertEq(token.balanceOf(user), 900 * 10**18);
    }
    
    function testTransferFrom() public {
        uint256 amount = 100 * 10**18;
        address recipient = address(0x789);
        
        // 先设置授权
        vm.prank(user);
        token.approve(address(permit2), amount);
        
        // 使用 Permit2 转移代币
        permit2.transferFrom(user, recipient, uint160(amount), address(token));
        
        // 验证转移成功
        assertEq(token.balanceOf(recipient), amount);
        assertEq(token.balanceOf(user), 900 * 10**18);
    }
} 