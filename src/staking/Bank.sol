// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./IBank.sol";

contract Bank is IBank {

    constructor() {}

    //每个地址的存款金额
    mapping(address => uint) public balances;

    //收款
    receive() external payable {
        deposit();
    }

    function deposit() public payable virtual {
        //存钱
        balances[msg.sender] += msg.value;
    }

    // 添加到Bank合约中
    function withdrawTo(uint amount, address to) public virtual {
        require(balances[msg.sender] >= amount ,"user Not enough balance");
        require(address(this).balance >= amount ,"contract Not enough balance");
        balances[msg.sender] -= amount;
        payable(to).transfer(amount);
    }

    function getUserBalance() external view returns(uint) {
        return balances[msg.sender];
    }

    function getContractBalance() external view returns(uint) {
        return address(this).balance;
    }
}
