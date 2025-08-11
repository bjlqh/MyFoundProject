// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IBank {
    
    function deposit() external payable;

    function withdrawTo(uint amount, address to) external;
}