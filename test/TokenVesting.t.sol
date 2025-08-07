// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../src/MyToken.sol";
import "../src/vesting/TokenVesting.sol";

contract TokenVestingTest is Test {
    TokenVesting public vesting;
    MyToken public token;
    address public owner = address(0x1);
    address public beneficiary = address(0x2);
    uint public constant TOTAL_AMOUNT = 1_000_000 * 1e18;

    function setUp() public {
        vm.startPrank(owner);
        token = new MyToken("MyToken", "MTK", TOTAL_AMOUNT);
        vesting = new TokenVesting(address(token), beneficiary);
        token.transfer(address(vesting), TOTAL_AMOUNT);
        vm.stopPrank();
    }

    // 测试在Cliff期内不能释放
    function testCannotReleaseBeforeCliff() public {
        //第11个月释放
        vm.warp(block.timestamp + 330 days);
        vm.prank(beneficiary);
        vm.expectRevert("No tokens to release");
        vesting.release();
    }

    //在释放期释放
    function testReleaseAfterCliff() public {
        //13个月之后释放
        vm.warp(block.timestamp + 395 days);
        
        uint releasable = vesting.releasableAmount();
        assertTrue(releasable > 0);

        uint balanceBefore = token.balanceOf(beneficiary);
        vm.prank(beneficiary);
        vesting.release();

        assertEq(token.balanceOf(beneficiary), balanceBefore + releasable);
    }

    //测试线性释放
    function testLinearVesting() public {
        // 测试关键时间点
        uint[] memory testTimes = new uint[](5);
        testTimes[0] = vesting.startTime() + 365 days + 182 days + 12 hours; // cliff后6个月(6*365/12=182.5≈183)
        testTimes[1] = vesting.startTime() + 365 days + 365 days; // cliff后12个月
        testTimes[2] = vesting.startTime() + 365 days + 547 days + 12 hours; // cliff后18个月(18*365/12=547.5)
        testTimes[3] = vesting.startTime() + 365 days + 730 days; // cliff后24个月(全部释放)
        testTimes[4] = vesting.startTime() + 365 days + 730 days + 183 days; // cliff后30个月(全部释放)


        string[] memory labels = new string[](5);
        labels[0] = "Cliff+6months";
        labels[1] = "Cliff+12months";
        labels[2] = "Cliff+18months";
        labels[3] = "Cliff+24months";
        labels[4] = "Cliff+30months";

        for(uint i = 0; i < testTimes.length; i++){
            vm.warp(testTimes[i]);

            uint expectedVested = vesting.vestedAmount();     //计算预期已释放金额
            uint releasable = vesting.releasableAmount();   //计算预期可释放金额
        
            console.log(labels[i]);
            console.log("Vested:", expectedVested / 1e18);
            console.log("Releasable:", releasable / 1e18);
            console.log("------------------");

            if(releasable > 0) {
                vm.prank(beneficiary);
                vesting.release();
            }
        }

        //最后应该释放完所有代币
        assertEq(vesting.released(), TOTAL_AMOUNT);
    }
}
