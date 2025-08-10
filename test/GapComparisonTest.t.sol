// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

// ========== 没有__gap的合约 ==========
contract StudentNoGapV1 is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    string public name;
    uint public age;
    
    constructor() {
        _disableInitializers();
    }
    
    function initialize(string memory _name, uint _age) public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
        name = _name;
        age = _age;
    }
    
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
    
    function getName() public view returns (string memory) {
        return name;
    }
    
    function getAge() public view returns (uint) {
        return age;
    }
}

contract StudentNoGapV2 is StudentNoGapV1 {
    uint public sex;
    uint public score;
    
    function setSex(uint _sex) public {
        sex = _sex;
    }
    
    function setScore(uint _score) public {
        score = _score;
    }
    
    function getSex() public view returns (uint) {
        return sex;
    }
    
    function getScore() public view returns (uint) {
        return score;
    }
}

// StudentNoGapV1升级版本 - 添加owner字段
contract StudentNoGapV1Upgraded is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    string public name;
    uint public age;
    address public newOwner;  // 新增字段！这会破坏存储布局
    
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
    
    function setNewOwner(address _owner) public {
        newOwner = _owner;
    }
    
    function getName() public view returns (string memory) {
        return name;
    }
    
    function getAge() public view returns (uint) {
        return age;
    }
    
    function getNewOwner() public view returns (address) {
        return newOwner;
    }
}

// ========== 有__gap的合约 ==========
contract StudentWithGapV1 is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    string public name;
    uint public age;
    uint[10] private __gap;  // 预留空间
    
    constructor() {
        _disableInitializers();
    }
    
    function initialize(string memory _name, uint _age) public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
        name = _name;
        age = _age;
    }
    
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
    
    function getName() public view returns (string memory) {
        return name;
    }
    
    function getAge() public view returns (uint) {
        return age;
    }
}

contract StudentWithGapV2 is StudentWithGapV1 {
    uint public sex;
    uint public score;
    uint[10] private __gap;  // 自己的预留空间
    
    function setSex(uint _sex) public {
        sex = _sex;
    }
    
    function setScore(uint _score) public {
        score = _score;
    }
    
    function getSex() public view returns (uint) {
        return sex;
    }
    
    function getScore() public view returns (uint) {
        return score;
    }
}

// StudentWithGapV1升级版本 - 使用__gap空间添加owner
contract StudentWithGapV1Upgraded is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    string public name;
    uint public age;
    address public newOwner;   // 使用__gap空间
    uint[9] private __gap;  // 减少1个槽位
    
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
    
    function setNewOwner(address _owner) public {
        newOwner = _owner;
    }
    
    function getName() public view returns (string memory) {
        return name;
    }
    
    function getAge() public view returns (uint) {
        return age;
    }
    
    function getNewOwner() public view returns (address) {
        return newOwner;
    }
}

contract GapComparisonTest is Test {
    ERC1967Proxy proxyNoGap;
    ERC1967Proxy proxyWithGap;
    
    address alice = address(0x1);
    address bob = address(0x2);
    
    function setUp() public {
        // 部署没有__gap的代理合约
        StudentNoGapV1 implNoGapV1 = new StudentNoGapV1();
        proxyNoGap = new ERC1967Proxy(
            address(implNoGapV1),
            abi.encodeWithSelector(StudentNoGapV1.initialize.selector, "Alice", 20)
        );
        
        // 部署有__gap的代理合约
        StudentWithGapV1 implWithGapV1 = new StudentWithGapV1();
        proxyWithGap = new ERC1967Proxy(
            address(implWithGapV1),
            abi.encodeWithSelector(StudentWithGapV1.initialize.selector, "Bob", 25)
        );
    }
    
    function testNoGapStorageCorruption() public {
        console.log("\n========== Testing Storage Corruption Without __gap ==========");
        
        // 1. Upgrade to V2
        StudentNoGapV2 implNoGapV2 = new StudentNoGapV2();
        StudentNoGapV1(address(proxyNoGap)).upgradeTo(address(implNoGapV2));        //这个方式的通用代码怎么表示的
        
        StudentNoGapV2 studentV2 = StudentNoGapV2(address(proxyNoGap));
        
        // 2. Set V2 data
        studentV2.setSex(1);     // Male
        studentV2.setScore(95);  // Score 95
        
        console.log("V2 Data:");
        console.log("Name:", studentV2.getName());
        console.log("Age:", studentV2.getAge());
        console.log("Sex:", studentV2.getSex());
        console.log("Score:", studentV2.getScore());
        
        // 3. Upgrade V1 implementation, add owner field
        StudentNoGapV1Upgraded implV1Upgraded = new StudentNoGapV1Upgraded();
        StudentNoGapV2(address(proxyNoGap)).upgradeTo(address(implV1Upgraded));
        
        StudentNoGapV1Upgraded studentUpgraded = StudentNoGapV1Upgraded(address(proxyNoGap));
        
        console.log("\nAfter V1 Upgrade:");
        console.log("Name:", studentUpgraded.getName());
        console.log("Age:", studentUpgraded.getAge());
        
        // 4. Read owner field - this will read the original sex value!
        address ownerValue = studentUpgraded.getNewOwner();
        console.log("Owner (should be 0x0, but reads sex value):", ownerValue);
        
        // 5. Read V2 data again
        StudentNoGapV2 studentV2After = StudentNoGapV2(address(proxyNoGap));
        console.log("\nRe-reading V2 Data (corrupted):");
        console.log("Sex (was 1, now reads):", studentV2After.getSex());
        console.log("Score (was 95, now reads):", studentV2After.getScore());
        
        // Verify data corruption
        // owner field reads the original sex value
        assertEq(uint256(uint160(ownerValue)), 1, "Owner field corrupted with sex value");
    }
    
    function testWithGapStorageSafety() public {
        console.log("\n========== Testing Storage Safety With __gap ==========");
        
        // 1. Upgrade to V2
        StudentWithGapV2 implWithGapV2 = new StudentWithGapV2();
        StudentWithGapV1(address(proxyWithGap)).upgradeTo(address(implWithGapV2));
        
        StudentWithGapV2 studentV2 = StudentWithGapV2(address(proxyWithGap));
        
        // 2. Set V2 data
        studentV2.setSex(2);     // Female
        studentV2.setScore(88);  // Score 88
        
        console.log("V2 Data:");
        console.log("Name:", studentV2.getName());
        console.log("Age:", studentV2.getAge());
        console.log("Sex:", studentV2.getSex());
        console.log("Score:", studentV2.getScore());
        
        // 3. Upgrade V1 implementation, use __gap space for owner
        StudentWithGapV1Upgraded implV1Upgraded = new StudentWithGapV1Upgraded();
        StudentWithGapV2(address(proxyWithGap)).upgradeTo(address(implV1Upgraded));
        
        StudentWithGapV1Upgraded studentUpgraded = StudentWithGapV1Upgraded(address(proxyWithGap));
        
        // 4. Set owner
        studentUpgraded.setNewOwner(alice);
        
        console.log("\nAfter V1 Upgrade:");
        console.log("Name:", studentUpgraded.getName());
        console.log("Age:", studentUpgraded.getAge());
        console.log("Owner:", studentUpgraded.getNewOwner());
        
        // 5. Read V2 data again
        StudentWithGapV2 studentV2After = StudentWithGapV2(address(proxyWithGap));
        console.log("\nRe-reading V2 Data (should be intact):");
        console.log("Sex (should still be 2):", studentV2After.getSex());
        console.log("Score (should still be 88):", studentV2After.getScore());
        
        // Verify data integrity
        assertEq(studentUpgraded.getNewOwner(), alice, "Owner should be set correctly");
        assertEq(studentV2After.getSex(), 2, "Sex should remain unchanged");
        assertEq(studentV2After.getScore(), 88, "Score should remain unchanged");
    }
    
    function testStorageSlotAnalysis() public {
        console.log("\n========== Storage Slot Analysis ==========");
        
        // Analyze storage layout without __gap
        console.log("\nStorage layout without __gap:");
        console.log("StudentNoGapV1:");
        console.log("  slot[0]: name (string)");
        console.log("  slot[1]: age (uint)");
        console.log("\nStudentNoGapV2 (inherits V1):");
        console.log("  slot[0]: name (inherited)");
        console.log("  slot[1]: age (inherited)");
        console.log("  slot[2]: sex (new)");
        console.log("  slot[3]: score (new)");
        console.log("\nStudentNoGapV1Upgraded (adds owner):");
        console.log("  slot[0]: name");
        console.log("  slot[1]: age");
        console.log("  slot[2]: owner (new) <- CONFLICT! Was sex position");
        
        // Analyze storage layout with __gap
        console.log("\nStorage layout with __gap:");
        console.log("StudentWithGapV1:");
        console.log("  slot[0]: name (string)");
        console.log("  slot[1]: age (uint)");
        console.log("  slot[2-11]: __gap[10] (reserved)");
        console.log("\nStudentWithGapV2 (inherits V1):");
        console.log("  slot[0]: name (inherited)");
        console.log("  slot[1]: age (inherited)");
        console.log("  slot[2]: sex (uses parent __gap)");
        console.log("  slot[3]: score (uses parent __gap)");
        console.log("  slot[4-11]: __gap remaining (parent)");
        console.log("  slot[12-21]: __gap[10] (own)");
        console.log("\nStudentWithGapV1Upgraded (uses __gap for owner):");
        console.log("  slot[0]: name");
        console.log("  slot[1]: age");
        console.log("  slot[2]: owner (uses __gap space) <- SAFE!");
        console.log("  slot[3-11]: __gap[9] (remaining)");
        console.log("\nResult: V2's sex and score positions unchanged, data safe!");
    }
}