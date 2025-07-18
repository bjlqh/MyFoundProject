// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console.sol";
import "forge-std/Test.sol";
import "forge-std/StdInvariant.sol";
import "../src/MyToken.sol";

contract MyTokenInvariantTest is Test {
    MyToken token;
    address[] public holders;

    function setUp() public {
        token = new MyToken("MyToken", "MTK");
        holders.push(address(this));
        
        //指定要fuzz合约
        targetContract(address(this));
    }

    // 供 invariant engine 调用的 handler
    function transferTo(address to, uint256 amount) public {
        vm.assume(to != address(0) && to != address(this));
        amount = bound(amount, 0, token.balanceOf(address(this)));
        if(amount > 0){
            token.transfer(to, amount);
            holders.push(to);
        }
    }

    function invariant_totalSupplyEqualsSumOfBalances() public view {
        uint sum = 0;
        for (uint i = 0; i < holders.length; i++) {
            address holder = holders[i];
            bool counted = false;
            for (uint j = 0; j < i; j++) {
                if (holders[j] == holder) {
                    counted = true;
                    break;
                }
            }
            if (!counted) {
                sum += token.balanceOf(holder);
            }
        }
        assertEq(sum, token.totalSupply());
    }
}