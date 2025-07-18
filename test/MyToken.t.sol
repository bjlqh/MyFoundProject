// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console.sol";
import "forge-std/Test.sol";
import "../src/MyToken.sol";

contract MyTokenTest is Test {
    MyToken token;
    uint256 sepoliaForkId;

    function setUp() public {
        uint forkBlock = 8129000;
        token = new MyToken("MyToken", "MTK");
        sepoliaForkId = vm.createSelectFork(vm.rpcUrl("sepolia"), forkBlock);
    }

    function testNameAndSymbol() public view {
        assertEq(token.name(), "MyToken");
        assertEq(token.symbol(), "MTK");
        console.log("name", token.name());
    }

    function testInitialSupply() public view {
        assertEq(token.balanceOf(address(this)), 1e10 * 1e18);
    }

    //更改msg.sender
    function testPrank() public {
        
        address alice = address(0x123);
        token.transfer(alice, 100);
        assertEq(token.balanceOf(alice), 100);
        
        //vm.prank(x)	只伪造下一次调用的 msg.sender = x
        //vm.startPrank(x) 伪造从现在起所有调用的 msg.sender = x，直到 stopPrank()
        vm.prank(alice);
        token.transfer(address(0x456), 100);

        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(address(0x456)), 100);
    }

    //修改时间区块
    function testWarp() public {
        uint256 newTime = 1_700_000_000;
        vm.warp(newTime);
        assertEq(block.timestamp, newTime);
    }

    //期望错误
    function testExpectRevert() public {
        vm.expectRevert(abi.encodeWithSignature(
            "ERC20InsufficientBalance(address,uint256,uint256)",
            address(this),
            1e10 * 1e18,
            1e30
        ));
        token.transfer(address(0x456), 1e30); // 超过余额，应该 revert
    }

    //断言合约执行错误
    function testExpectRevert2() public {
        vm.startPrank(address(0x123));
        MyToken mt = new MyToken("MyToken", "MTK");
        vm.stopPrank();

        vm.startPrank(address(0x456));
        bytes memory data = abi.encodeWithSignature("NotOwner(address)", 0x456);
        vm.expectRevert(data);
        mt.transferOwnership(address(0x456));
        vm.stopPrank();
    }

    //区块号的变更
    function testRoll() public {
        //当前区块号
        uint256 blockNumber = block.number;
        console.log("blockNumber", blockNumber);

        //设置新的嗯区块号
        vm.roll(1001);
        assertEq(block.number, 1001);
    }

    // 设置代币余额并转账测试
    function testDeal() public {
        address user = address(0x888);
        // 设置 user 的 MyToken 余额为 100 ether
        deal(address(token), user, 100 ether);
        assertEq(token.balanceOf(user), 100 ether);

        // 伪造 user 作为 msg.sender 转 80 个代币给 recipient
        address recipient = address(0x999);
        vm.prank(user);
        token.transfer(recipient, 80 ether);

        // 检查 user 剩余 20 ether，recipient 收到 80 ether
        assertEq(token.balanceOf(user), 20 ether);
        assertEq(token.balanceOf(recipient), 80 ether);
    }

    //fork
    function testFork() public {
        vm.selectFork(sepoliaForkId);
        assertEq(vm.activeFork(), sepoliaForkId);
        assertGe(token.balanceOf(address(this)), 1e10 * 1e18);
    }

    function testFuzz(address to, uint256 amount) public {
        vm.assume(to != address(0));
        vm.assume(to != address(this));
        amount = bound(amount, 0, 10000 * 10 ** 18);
        //转账
        token.transfer(to, amount);
        assertEq(token.balanceOf(to), amount);
    } 
} 