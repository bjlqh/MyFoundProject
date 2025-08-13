// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../src/rebase/RebaseToken.sol";

contract RebaseTokenTest is Test {
    RebaseToken public token;
    address public alice;
    address public bob;
    address public owner;

    function setUp() public {
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        owner = address(this);
        vm.prank(owner);
        token = new RebaseToken("RebaseToken", "RTK");
    }

    function testRebaseAfterOneYear() public {
        uint amount = 1000 * 1e18;
        token.transfer(alice, amount);
        vm.assertEq(token.balanceOf(alice), amount);

        //模拟一年后
        vm.warp(block.timestamp + 365 days + 1);

        token.rebase();

        //检查rebase倍数
        assertEq(token.rebaseMultiplier(), 0.99e18);

        //检查余额
        assertEq(token.balanceOf(alice), amount * 99 / 100);
        //检查总供应量
        assertEq(token.totalSupply(), token.INITIAL_TOTAL_SUPPLY() * 99 / 100);


        //模拟5年以后
        vm.warp(block.timestamp + 4 * 365 days);
        token.rebase();

        //检查rebase倍数
        assertEq(token.rebaseMultiplier(), 0.99 ** 5 * 1e18);

        //检查余额
        uint expectedBalance = amount * 99 ** 5 / 100 ** 5;
        assertEq(token.balanceOf(alice), expectedBalance);

        //检查总供应量
        assertEq(token.totalSupply(), token.INITIAL_TOTAL_SUPPLY() * 99 ** 5 / 100 ** 5);
    }

    function testTransferAfterRebase() public {
        uint256 transferAmount = 1000 * 1e18;
        token.transfer(alice, transferAmount);
        
        // 一年后rebase
        vm.warp(block.timestamp + 365 days + 1);
        token.rebase();
        
        // alice的余额应该是990个代币
        uint256 aliceBalance = token.balanceOf(alice);
        assertEq(aliceBalance, 990 * 1e18);
        
        // alice转账给bob
        vm.prank(alice);
        token.transfer(bob, 100 * 1e18);
        
        // 检查转账后的余额 - 允许微小的精度损失
        uint256 aliceBalanceAfter = token.balanceOf(alice);
        uint256 bobBalance = token.balanceOf(bob);
        
        // 允许最多1 wei的精度损失
        assertApproxEqAbs(aliceBalanceAfter, 890 * 1e18, 1);
        assertApproxEqAbs(bobBalance, 100 * 1e18, 1);
    }
}
