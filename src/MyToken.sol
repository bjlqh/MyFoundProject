// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract MyToken is ERC20, ERC20Permit {
 
    address public owner;

    constructor(
        string memory name_,
        string memory symbol_
    ) ERC20(name_, symbol_) ERC20Permit(name_) {
        owner = msg.sender;
        _mint(msg.sender, 1000 * 1e18); // 增加初始供应量
    }

    error NotOwner(address caller);
    
    function transferOwnership(address newOwner) public {
        if (msg.sender != owner) {
            revert NotOwner(msg.sender);
        }
        owner = newOwner;
    }
}
