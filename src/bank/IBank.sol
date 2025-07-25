// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

interface IBank {
    
    function deposit() external payable;

    function withdraw() external;
}

