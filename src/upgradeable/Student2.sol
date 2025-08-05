// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract Student2 is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    struct User {
        string name; //保持原有字段
        uint256 age; //新增字段
    }

    mapping(uint => User) public users;
    uint public total;

    uint[46] private __gap; //减少2个槽位

    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
        total = 0;
    }

    //兼容旧版本
    function addUser(uint id, string memory name) external onlyOwner {
        require(bytes(users[id].name).length == 0, "User exists");
        users[id] = User(name, 0);
        total++;
    }

    function addUserV2(
        uint id,
        string memory name,
        uint age
    ) external onlyOwner {
        require(bytes(users[id].name).length == 0, "User exists");
        users[id] = User(name, age);
        total++;
    }

    //兼容旧版本
    function getUser(uint id) external view returns (string memory) {
        return users[id].name;
    }

    function getUserV2(uint id) external view returns (string memory, uint) {
        return (users[id].name, users[id].age);
    }

    function updateUserAge(uint id, uint age) external onlyOwner {
        require(bytes(users[id].name).length != 0, "User not exists");
        users[id].age = age;
    }

    function version() external pure returns (string memory) {
        return "2.0.0";
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
