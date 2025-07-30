// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MyWallet {
    
    string public name; //slot[0]
    
    mapping(address => bool) private approved; //slot[1]
    
    address public owner; //slot[2]

    modifier auth() {
        address _owner;
        assembly {
            //owner 存在 slot[2]
            _owner := sload(2)
        }
        require(msg.sender == _owner, "Not authorized");
        _;
    }

    constructor(string memory _name) {
        name = _name;
        assembly {
            sstore(2, caller()) //在slot[2]写入
        }
    }

    function transferOwernship(address _addr) public auth {
        require(_addr != address(0), "New owner is the zero address");
        //读取
        address currentOwner;
        assembly {
            currentOwner := sload(2)
        }
        require(currentOwner != _addr, "New owner is the same as the old owner");
        //赋值
        assembly {
            sstore(2, _addr)
        }
    }
}
