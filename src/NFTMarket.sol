// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./MyToken.sol";
import "./MyERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract NFTMarket is IERC721Receiver {
    MyERC721 public nft;
    MyToken public token;
    
    using ECDSA for bytes32;

    // 白名单签名者地址
    address public whitelistSigner;
    
    // 已使用的签名映射，防止重放攻击
    mapping(bytes32 => bool) public usedSignatures;

    constructor(address _token, address _nft, address _whitelistSigner) {
        token = MyToken(_token);
        nft = MyERC721(_nft);
        whitelistSigner = _whitelistSigner;
    }

    struct Listing {
        address seller;
        uint price;
    }
    mapping(uint => Listing) public listings;

    uint256[] public listedTokenIds;
    //tokenId到index的映射
    mapping(uint256 => uint256) public tokenIdToIndex;
    mapping(uint256 => bool) public isListed;

    //上架事件
    event Listed(
        address indexed nft,
        uint256 indexed tokenId,
        address indexed seller,
        uint256 price
    );
    //购买事件
    event Bought(
        address indexed nft,
        uint256 indexed tokenId,
        address indexed buyer,
        address seller,
        uint256 price
    );
    
    // 白名单购买事件
    event WhitelistBought(
        address indexed nft,
        uint256 indexed tokenId,
        address indexed buyer,
        address seller,
        uint256 price
    );

    error NotOwner();
    error InvalidPrice();
    error InvalidSignature();
    error SignatureAlreadyUsed();
    error NotWhitelisted();

    //上架
    function list(uint tokenId, uint price) external {
        //token不属于owner
        if (nft.ownerOf(tokenId) != msg.sender) revert NotOwner();
        if (price <= 0) revert InvalidPrice();
        nft.safeTransferFrom(msg.sender, address(this), tokenId);
        listings[tokenId] = Listing({seller: msg.sender, price: price});
        listedTokenIds.push(tokenId);
        tokenIdToIndex[tokenId] = listedTokenIds.length - 1;
        isListed[tokenId] = true;
        emit Listed(address(nft), tokenId, msg.sender, price);
    }

    error NotListed();
    error CannotBuyOwn();
    error InvalidPayment();
    error InSufficientFunds();

    //购买
    function buyNFT(uint tokenId, uint price) external {
        Listing memory item = listings[tokenId];
        if (item.seller == address(0)) revert NotListed();
        if (msg.sender == item.seller) revert CannotBuyOwn();
        if (price != item.price) revert InvalidPayment();
        if (token.balanceOf(msg.sender) < item.price)
            revert InSufficientFunds();

        //支付token到market
        bool success = token.transferFrom(
            msg.sender,
            address(this),
            item.price
        );
        require(success, "Token transferFrom failed");

        //转移所有权给买家
        nft.safeTransferFrom(address(this), msg.sender, tokenId);

        //清除
        delete listings[tokenId];

        // 移除 listedTokenIds 中的 tokenId
        removeFromListedTokenIds(tokenId);

        //购买
        emit Bought(address(nft), tokenId, msg.sender, item.seller, item.price);
    }

    function removeFromListedTokenIds(uint256 tokenId) internal {
        if(!isListed[tokenId]){
            return;
        }
        uint256 index = tokenIdToIndex[tokenId];
        uint256 lastIndex = listedTokenIds.length - 1;
        if(index != lastIndex){
            //lastIndex元素换到index位置
            uint256 lastTokenId = listedTokenIds[lastIndex];
            listedTokenIds[index] = lastTokenId;
            tokenIdToIndex[lastIndex] = index;
        }
        listedTokenIds.pop();
        delete tokenIdToIndex[tokenId];
        delete isListed[tokenId];
    }

    // 白名单购买函数
    function permitBuy(
        uint tokenId,
        uint price,
        uint256 deadline,
        bytes memory signature
    ) external {
        Listing memory item = listings[tokenId];
        if (item.seller == address(0)) revert NotListed();
        if (msg.sender == item.seller) revert CannotBuyOwn();
        if (price != item.price) revert InvalidPayment();
        if (token.balanceOf(msg.sender) < item.price)
            revert InSufficientFunds();
        if (deadline < block.timestamp) revert("Signature expired");

        // 验证白名单签名
        bytes32 messageHash = keccak256(abi.encodePacked(
            msg.sender,
            tokenId,
            price,
            deadline
        ));
        
        bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash();
        address signer = ethSignedMessageHash.recover(signature);
        
        if (signer != whitelistSigner) revert InvalidSignature();
        
        // 检查签名是否已使用
        bytes32 signatureHash = keccak256(signature);
        if (usedSignatures[signatureHash]) revert SignatureAlreadyUsed();
        usedSignatures[signatureHash] = true;

        //支付token到market
        bool success = token.transferFrom(
            msg.sender,
            address(this),
            item.price
        );
        require(success, "Token transferFrom failed");

        //转移所有权给买家
        nft.safeTransferFrom(address(this), msg.sender, tokenId);

        //清除
        delete listings[tokenId];

        // 移除 listedTokenIds 中的 tokenId
        removeFromListedTokenIds(tokenId);

        //白名单购买
        emit WhitelistBought(address(nft), tokenId, msg.sender, item.seller, item.price);
    }

    function getListedTokenIdsLength() public view returns (uint256) {
        return listedTokenIds.length;
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
