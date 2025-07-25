// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
contract Counter {
    uint256 public number;

    function setNumber(uint256 newNumber) public {
        number = newNumber;
        //console.log("Counter set to =============:", number);
    }

    function increment() public {
        number++;
    }
}
