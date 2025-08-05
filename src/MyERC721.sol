// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract MyERC721 is ERC721URIStorage {

    uint256 private _tokenIds;

    constructor(string memory name_, string memory symbol_) ERC721(name_, symbol_) {

    }
    
    function mint(address student, string memory tokenURI) public returns (uint256) {
        _tokenIds++;
        uint256 newItemId = _tokenIds;
        _mint(student, newItemId);
        _setTokenURI(newItemId, tokenURI);
        return newItemId;
    }

}