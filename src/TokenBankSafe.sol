// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./MyToken.sol";

contract TokenBankSafe {

    mapping (address => uint256) public balances;
    
    //多签钱包地址
    address public admin;

    //address private tokenAddress;
    MyToken private token;

    constructor(address _tokenAddress, address _admin){
        token = MyToken(_tokenAddress);
        admin = _admin;
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

    //用户可以提取自己存的token
    function withdraw(address user, uint amount) public onlyOwners {
        require(amount > 0, "amount must be greater than 0");
        require(balances[user] >= amount, "Insufficient Balance");

        balances[user] -= amount;
        bool succ = token.transfer(user, amount);

        require(succ, "failed to transfer");
    }


    modifier onlyOwners() {
        require(msg.sender == admin, "only admin can call");
        _;
    }

    function setAdmin(address newAdmin) public onlyOwners {
        require(newAdmin != address(0), "new admin is the zero address");
        admin = newAdmin;
    }

}