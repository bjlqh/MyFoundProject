// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestTokenB is ERC20 {
    constructor() ERC20("Test Token B", "TTB") {
        _mint(msg.sender, 1000000 * 10**18); // 铸造100万个代币
    }
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}