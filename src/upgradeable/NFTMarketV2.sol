// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../MyToken.sol";
import "./MyERC721Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract NFTMarketV2 is 
    Initializable, 
    IERC721Receiver, 
    OwnableUpgradeable, 
    UUPSUpgradeable 
{
    MyERC721Upgradeable public nft;
    MyToken public token;
    
    using ECDSA for bytes32;

    // 白名单签名者地址
    address public whitelistSigner;
    
    // 已使用的签名映射，防止重放攻击
    mapping(bytes32 => bool) public usedSignatures;
    
    // 新增：离线签名上架功能的已使用签名映射
    mapping(bytes32 => bool) public usedListingSignatures;

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
    
    // 新增：离线签名上架事件
    event ListedWithSignature(
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
    error NotListed();
    error CannotBuyOwn();
    error InvalidPayment();
    error InSufficientFunds();
    error NotApprovedForAll();
    error ListingSignatureAlreadyUsed();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _token, 
        address _nft, 
        address _whitelistSigner
    ) public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
        
        token = MyToken(_token);
        nft = MyERC721Upgradeable(_nft);
        whitelistSigner = _whitelistSigner;
    }

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

    // 新增：离线签名上架功能
    function listWithSignature(
        uint256 tokenId,
        uint256 price,
        uint256 deadline,
        bytes memory signature
    ) external {
        if (price <= 0) revert InvalidPrice();
        if (deadline < block.timestamp) revert("Signature expired");
        
        address tokenOwner = nft.ownerOf(tokenId);
        
        // 检查市场合约是否被授权操作所有NFT
        if (!nft.isApprovedForAll(tokenOwner, address(this))) {
            revert NotApprovedForAll();
        }
        
        // 验证签名
        bytes32 messageHash = keccak256(abi.encodePacked(
            tokenId,
            price,
            deadline,
            address(this) // 包含合约地址防止跨合约重放
        ));
        
        bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash();
        address signer = ethSignedMessageHash.recover(signature);
        
        if (signer != tokenOwner) revert InvalidSignature();
        
        // 检查签名是否已使用
        bytes32 signatureHash = keccak256(signature);
        if (usedListingSignatures[signatureHash]) revert ListingSignatureAlreadyUsed();
        usedListingSignatures[signatureHash] = true;
        
        // 转移NFT到市场合约
        nft.safeTransferFrom(tokenOwner, address(this), tokenId);
        
        // 创建listing
        listings[tokenId] = Listing({seller: tokenOwner, price: price});
        listedTokenIds.push(tokenId);
        tokenIdToIndex[tokenId] = listedTokenIds.length - 1;
        isListed[tokenId] = true;
        
        emit ListedWithSignature(address(nft), tokenId, tokenOwner, price);
    }

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
            tokenIdToIndex[lastTokenId] = index;
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

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

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