// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract Student1 is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    
    struct User {
        string name;
    }

    mapping(uint => User) public users;     //slot[0]
    uint public total;                      //slot[1]

    uint[48] private __gap;     //存储间隙，为未来升级预留空间

    constructor() {
        _disableInitializers();     //UUPSUpgradeable
    }


    function initialize() public initializer {      //UUPSUpgradeable
        __Ownable_init();           //初始化所有管理，设置调用者为合约所有者。
        __UUPSUpgradeable_init();   //初始化UUPS升级功能
        total = 0;                  //初始化变量
    }

    function addUser(uint id, string memory name) external onlyOwner {
        require(bytes(users[id].name).length == 0, "User exists");
        users[id] = User(name);
        total++;
    }

    function getUser(uint id) external view returns(string memory) {
        return users[id].name;  
    }

    function version() external pure returns(string memory) {
        return "1.0.0";
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

}