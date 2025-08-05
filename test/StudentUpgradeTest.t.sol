// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/console.sol";
import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/upgradeable/Student1.sol";
import "../src/upgradeable/Student2.sol";

contract StudentUpgradeTest is Test {
    Student1 public student1;
    Student2 public student2;
    address public owner = address(0x1);
    Student1 public student1Impl;
    Student2 public student2Impl;
    ERC1967Proxy public proxy;

    function setUp() public {
        vm.startPrank(owner);

        student1Impl = new Student1();
        student2Impl = new Student2();

        bytes memory initData = abi.encodeWithSelector(
            Student1.initialize.selector
        );

        /**
         * 部署代理合约
         * 指定逻辑合约地址，告诉代理合约"所有函数调用都转发到这个地址"
         * initData: 初始化参数，代理合约部署以后立即调用initialize函数
         */ 
        proxy = new ERC1967Proxy(address(student1Impl), initData);

        // 升级前使用student1，升级后使用student2
        student1 = Student1(address(proxy));
        // student2变量可以让我吗能够使用Student2的接口(包括新增函数)来与同一个代理合约交互。 
        student2 = Student2(address(proxy));
        /**
         * 以上方式
         */

        vm.stopPrank();
    }

    // 测试存储布局兼容性
    function testStorageLayoutCompatibility() public {
        vm.startPrank(owner);
        
        //v1中添加用户
        student1.addUser(1, "Alice");
        student1.addUser(2, "Bob");

        //验证V1
        assertEq(student1.getUser(1), "Alice");
        assertEq(student1.total(), 2);

        //升级到V2
        student1.upgradeTo(address(student2Impl));

        //验证V2,升级后数据保持不变
        assertEq(student2.getUser(1), "Alice");
        assertEq(student2.total(), 2);
    
        //验证v2新功能
        (string memory name, uint age) = student2.getUserV2(1);
        assertEq(name, "Alice");
        assertEq(age, 0);

        student2.addUserV2(3, "Charlie", 18);
        (name, age) = student2.getUserV2(3);
        assertEq(name, "Charlie");
        assertEq(age, 18);

        student2.updateUserAge(3, 28);
        (name, age) = student2.getUserV2(3);
        assertEq(age, 28);

        vm.stopPrank();
    }
}
