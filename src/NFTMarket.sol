// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./MyToken.sol";
import "./MyERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract NFTMarket is IERC721Receiver {
    
    MyERC721 public nft;
    MyToken public token;

    constructor(address _token, address _nft){
        token = MyToken(_token);
        nft = MyERC721(_nft);
    }

    struct Listing {
        address seller;
        uint price;
    }
    mapping(uint => Listing) public listings;

    //上架事件
    event Listed(address indexed nft, uint256 indexed tokenId, address indexed seller, uint256 price);
    //购买事件
    event Bought(address indexed nft, uint256 indexed tokenId, address indexed buyer, address seller, uint256 price);

    error NotOwner();
    error InvalidPrice();

    //上架
    function list(uint tokenId, uint price) external {
        //token不属于owner
        if(nft.ownerOf(tokenId) != msg.sender) revert NotOwner();
        if(price <= 0) revert InvalidPrice();
        nft.safeTransferFrom(msg.sender, address(this), tokenId);
        listings[tokenId] = Listing({seller: msg.sender, price: price}); 
        emit Listed(address(nft), tokenId, msg.sender, price);
    }

    error NotListed();
    error CannotBuyOwn();
    error InvalidPayment();
    error InSufficientFunds();

    //购买
    function buyNFT(uint tokenId, uint price) external {
        Listing memory item = listings[tokenId];
        if(item.seller == address(0)) revert NotListed();
        if(msg.sender == item.seller) revert CannotBuyOwn();
        if(price != item.price) revert InvalidPayment();
        if(token.balanceOf(msg.sender) < item.price) revert InSufficientFunds();

        //支付token到market
        bool success = token.transferFrom(msg.sender, address(this), item.price);
        require(success, "Token transferFrom failed");

        //转移所有权给买家
        nft.safeTransferFrom(address(this), msg.sender, tokenId);
        
        //清除
        delete listings[tokenId];

        //购买
        emit Bought(address(nft), tokenId, msg.sender, item.seller, item.price);
    }

    /**
     * 当 NFT 合约调用 safeTransferFrom 把 NFT 转给 NFTMarket 时，
     * 会检查 NFTMarket 是否实现了 onERC721Received，
     * 如果没有就会报错。
     */
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
