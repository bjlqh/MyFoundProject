// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/console.sol";
import "forge-std/Test.sol";
import "../../src/bank/Bank.sol";

contract BankTest is Test {
    Bank bank;
    address owner = address(0x111111); 

    function setUp() public {
        vm.prank(owner);
        bank = new Bank();
    }

    //存款更新余额
    function testDepositUpdatesBalance() public {
        address user = address(0x123);
        vm.deal(user, 10 ether);

        vm.startPrank(user);

        bank.deposit{value: 1 ether}();
        assertEq(bank.balances(user), 1 ether);

        bank.deposit{value: 2 ether}();
        assertEq(bank.balances(user), 3 ether);
        vm.stopPrank();
    }

    //1个用户存款
    function testTop3With1User() public {
        address user = address(0x123);
        vm.deal(user, 10 ether);
        vm.prank(user);

        bank.deposit{value: 1 ether}();
        assertEq(bank.balances(user), 1 ether);
        assertEq(bank.top3(0), user);
    }

    //2个用户存款
    function testTop3With2Users() public {
        address user1 = address(0x123);
        address user2 = address(0x456);

        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);

        vm.prank(user1);
        bank.deposit{value: 1 ether}();

        vm.prank(user2);
        bank.deposit{value: 2 ether}();

        assertEq(bank.getTop3Len(), 2);

        //检查top3是否是user1和user2
        bool f1 = false;
        bool f2 = false;
        for(uint i = 0; i < bank.getTop3Len(); i++){
            if(bank.top3(i) == user1){
                f1 = true;
            }
            if(bank.top3(i) == user2){
                f2 = true;
            }
        }
        assertTrue(f1 && f2);
    }

    //3个用户存款
    function testTop3With3Users() public {
        address user1 = address(0x123);
        address user2 = address(0x456);
        address user3 = address(0x789);

        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(user3, 10 ether);

        vm.prank(user1);
        bank.deposit{value: 1 ether}();

        vm.prank(user2);
        bank.deposit{value: 2 ether}();

        vm.prank(user3);
        bank.deposit{value: 3 ether}();

        assertEq(bank.getTop3Len(), 3);

        //检查top3是否是user1,user2,user3
        bool f1 = false;
        bool f2 = false;
        bool f3 = false;

        for(uint i = 0; i < bank.getTop3Len(); i++){
            if(bank.top3(i) == user1){
                f1 = true;
            }
            if(bank.top3(i) == user2){
                f2 = true;
            }
            if(bank.top3(i) == user3){
                f3 = true;
            }
        }
        assertTrue(f1 && f2 && f3);
    }

    //4个用户存款
    function testTop3With4Users() public {
        address user1 = address(0x123);
        address user2 = address(0x456);
        address user3 = address(0x789);
        address user4 = address(0x101);

        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(user3, 10 ether);
        vm.deal(user4, 10 ether);

        vm.prank(user1);
        bank.deposit{value: 1 ether}();
        
        vm.prank(user2);
        bank.deposit{value: 2 ether}();

        vm.prank(user3);
        bank.deposit{value: 3 ether}();

        vm.prank(user4);
        bank.deposit{value: 4 ether}();

        assertEq(bank.getTop3Len(), 3);

        //检查top3是否是user1,user2,user3
        bool f1 = false;
        bool f2 = false;
        bool f3 = false;
        bool f4 = false;

        for(uint i = 0; i < bank.getTop3Len(); i++){
            if(bank.top3(i) == user2){
                f1 = true;
            }
            if(bank.top3(i) == user2){
                f2 = true;
            }
            if(bank.top3(i) == user3){
                f3 = true;
            }
            if(bank.top3(i) == user4){
                f4 = true;
            }
        }
        assertFalse(f1);
        assertTrue(f2 && f3 && f4);
    }

    //同一个用户多次存款
    function testDepositMultipleTimes() public {
        address user1 = address(0x123);
        address user2 = address(0x456);
        address user3 = address(0x789);
        address user4 = address(0x101);

        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(user3, 10 ether);
        vm.deal(user4, 10 ether);

        vm.startPrank(user1);
        bank.deposit{value: 1 ether}();
        bank.deposit{value: 1 ether}();
        bank.deposit{value: 1 ether}();
        bank.deposit{value: 1 ether}();
        vm.stopPrank();

        vm.prank(user2);
        bank.deposit{value: 2 ether}();

        vm.prank(user3);
        bank.deposit{value: 3 ether}();

        vm.prank(user4);
        bank.deposit{value: 4 ether}();

        assertEq(bank.getTop3Len(), 3);

        //检查top3是否是user1,user2,user3
        bool f1 = false;
        bool f2 = false;
        bool f3 = false;
        bool f4 = false;

        for(uint i = 0; i < bank.getTop3Len(); i++){
            if(bank.top3(i) == user1){
                f1 = true;
            }
            if(bank.top3(i) == user2){
                f2 = true;
            }
            if(bank.top3(i) == user3){
                f3 = true;
            }
            if(bank.top3(i) == user4){
                f4 = true;
            }
        }
        assertFalse(f2);
        assertTrue(f1 && f3 && f4);
    }

    //只有owner可以提款
    function testOnlyOwnerCanWithdraw() public {
        address user = address(0x123);
        vm.deal(user, 10 ether);
        vm.prank(user);
        //存款
        bank.deposit{value: 1 ether}();

        //非owner提款
        vm.prank(user);
        vm.expectRevert("Not the owner.");
        bank.withdraw();

        //owner提款
        vm.prank(owner);
        bank.withdraw();

        //余额清零
        assertEq(bank.balances(user), 0 ether);
        assertEq(bank.getDepositLen(), 0 ether);
        assertEq(bank.getTop3Len(), 0 ether);
    }
}