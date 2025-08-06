// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract StudentV1 {
    //基础变量
    string public name;     //slot[0]
    uint public age;        //slot[1]
    //新增字段
    string public desc;     //slot[2]

    //预留槽位
    uint[9] private __gap;  //之前是10，因为新增了一个字段，再不影响子类的storge slot，所以必须减1
}

contract StudentV2 is StudentV1 {
    //新增变量,使用父合约的__gap空间
    uint public sex;         //slot[12]
    uint public score;       //slot[13]

    uint[10] private __gap;
}

contract StudentV3 is StudentV2 {
    //新增变量
    string public addr;     //slot[24]
    uint public phone;      //slot[25]
}

