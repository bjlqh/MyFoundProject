// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../src/staking/StakingPool.sol";
import "../src/staking/Bank.sol";
import {MyToken} from "../src/MyToken.sol";

contract StakingPoolTest is Test {
    StakingPool public stakingPool;
    Bank public bank;
    MyToken public kkToken;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        bank = new Bank();
        kkToken = new MyToken("KK Token", "KK", 0); // 不预铸造代币
        stakingPool = new StakingPool(address(kkToken), address(bank));
        
        // 将kkToken的所有权转移给StakingPool，使其能够mint
        kkToken.transferOwnership(address(stakingPool));

        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
        vm.deal(address(stakingPool), 10 ether); // 给合约一些ETH用于unstake
    }

    function testStake() public {
        vm.startPrank(alice);
        stakingPool.stake{value: 1 ether}();
        assertEq(stakingPool.balanceOf(alice), 1 ether);
        vm.stopPrank();
    }

    function testUnstake() public {
        vm.startPrank(alice);
        stakingPool.stake{value: 1 ether}();
        stakingPool.unstake(0.5 ether);
        assertEq(stakingPool.balanceOf(alice), 0.5 ether);
        assertEq(alice.balance, 9.5 ether);
        vm.stopPrank();
    }

    function testClaim() public {
        vm.startPrank(alice);
        stakingPool.stake{value: 1 ether}();
        
        // 推进10个区块
        vm.roll(block.number + 10);
        
        uint256 earnedBefore = stakingPool.earned(alice);
        console.log("alice earned before claim: ", earnedBefore);
        
        stakingPool.claim();
        uint256 balance = kkToken.balanceOf(alice);
        console.log("alice of kkToken balance: ", balance);
        assertTrue(balance > 0);
        vm.stopPrank();
    }

    function testEarned() public {
        vm.startPrank(alice);
        stakingPool.stake{value: 1 ether}();
        vm.stopPrank();
    
        // 推进5个区块
        vm.roll(block.number + 5);
        
        vm.startPrank(bob);
        stakingPool.stake{value: 1 ether}();
        vm.stopPrank();
    
        // 再推进10个区块，让Bob也能获得奖励
        vm.roll(block.number + 10);
    
        uint256 aliceEarned = stakingPool.earned(alice);
        uint256 bobEarned = stakingPool.earned(bob);
        
        console.log("aliceEarned: ", aliceEarned);
        console.log("bobEarned: ", bobEarned);
    
        assertTrue(aliceEarned > 0);
        assertTrue(bobEarned > 0);
        // Alice应该比Bob赚得更多，因为她质押时间更长
        assertTrue(aliceEarned > bobEarned);
    }
}
