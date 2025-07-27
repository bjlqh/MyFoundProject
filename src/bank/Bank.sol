// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./IBank.sol";

contract Bank is IBank {

    address public owner;

    constructor(){
        owner = msg.sender;
    }
    
    //每个地址的存款金额
    mapping (address => uint) public balances;

    //存钱的用户
    address[] public depositors;

    //top3
    address[] public top3;

    //收款
    receive() external payable {
        deposit();
    }

    function deposit() public payable virtual {
        if(balances[msg.sender] == 0){
            //添加新用户
            depositors.push(msg.sender);
        }
        //存钱
        balances[msg.sender] += msg.value;
        
        //当前用户的存款
        uint balance = balances[msg.sender];
        
        //往top3里面插入地址，top3只能存3个存入金额最长的地址
        bool inTop3 = false;
        for(uint i = 0; i < top3.length; i++){
            if(top3[i] == msg.sender){
                inTop3 = true;
                break;
            }
        }
        if(!inTop3){
            if(top3.length < 3){
                top3.push(msg.sender);      //插入用户
            }else {
                //找出当前top3中最小余额的用户
                uint minIdx = 0;
                uint minBalance = balances[top3[0]];

                for (uint i = 1; i < 3; i++){
                    if(balances[top3[i]] < minBalance){
                        //更新最小值
                        minBalance = balances[top3[i]];
                        minIdx = i;
                    }
                }
                
                //当前余额比最小值大，那就替换
                if(balance > minBalance){
                    top3[minIdx] = msg.sender;
                }
            }
        }
    }

    //只有管理员才能提走资金
    function withdraw() public virtual {
        require(msg.sender == owner, "Not the owner.");
        payable(owner).transfer(address(this).balance);

        for (uint i = 0; i < depositors.length; i++) {
            balances[depositors[i]] = 0;
        }
        delete depositors;
        delete top3;
    }

    function getTop3Len() public view returns (uint){
        return top3.length;
    }

    function getDepositLen() public  view  returns (uint) {
        return depositors.length;
    }
}