// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "../MyToken.sol";

contract TokenBank {

    mapping (address => uint256) public balances;

    //address private tokenAddress;
    MyToken private token;

    constructor(address _tokenAddress){
        token = MyToken(_tokenAddress);
    }

    //记录每个地址存的数量
    function deposit(uint amount) public {
        require(amount > 0, "amount must be greater than 0");

        //转移token到当前合约
        bool success = token.transferFrom(msg.sender, address(this), amount);
        require(success, "failed to transferFrom");

        //记录
        balances[msg.sender] += amount;
    }

    // 使用permit进行离线签名授权存款
    function permitDeposit(
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        require(amount > 0, "amount must be greater than 0");
        require(deadline >= block.timestamp, "permit expired");

        // 使用permit授权
        token.permit(msg.sender, address(this), amount, deadline, v, r, s);
        
        // 转移token到当前合约
        bool success = token.transferFrom(msg.sender, address(this), amount);
        require(success, "failed to transferFrom");

        // 记录
        balances[msg.sender] += amount;
    }

    //用户可以提取自己存的token
    function withdraw(uint amount) public {
        require(amount > 0, "amount must be greater than 0");
        require(balances[msg.sender] >= amount, "Insufficient Balance");

        balances[msg.sender] -= amount;
        bool succ = token.transfer(msg.sender, amount);

        require(succ, "failed to transfer");
    }

}