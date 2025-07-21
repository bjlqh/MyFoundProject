// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MyToken is ERC20 {
 
    address public owner;

    constructor(
        string memory name_,
        string memory symbol_
    ) ERC20(name_, symbol_) {
        _mint(msg.sender, 100 * 1e18);
    }

    error NotOwner(address caller);
    function transferOwnership(address newOwner) public {
        if (msg.sender != owner) {
            revert NotOwner(msg.sender);
        }
        owner = newOwner;

    }
}
