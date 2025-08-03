// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../MyERC721.sol";
import "../MyToken.sol";
import "./MerkleProof.sol";

contract AirdropMerkleNFTMarket is IERC721Receiver {
    MyERC721 public nft;
    MyToken public token;

    using MerkleProof for bytes32[];

    //merkle树根
    bytes32 public merkleRoot;

    //优惠折扣比例
    uint public constant DISCOUNT_BPS = 5000;
    uint public constant BPS_DENOMINATOR = 10000;

    //已使用的nonce映射，防止重放攻击
    mapping(address => uint) public usedNonces;

    constructor(address _token, address _nft, bytes32 _merkleRoot) {
        token = MyToken(_token);
        nft = MyERC721(_nft);
        merkleRoot = _merkleRoot;
    }

    struct Listing {
        address seller;
        uint price;
    }

    //上架
    mapping(uint => Listing) public listings;

    uint[] public listedTokenIds;

    //tokenId对应上架数组的索引位置
    mapping(uint => uint) public tokenIdToIndex;

    //是否上架
    mapping(uint => bool) public isListed;

    event Listed(
        address indexed nft,
        uint indexed tokenId,
        address indexed seller,
        uint price
    );

    event Bought(
        address indexed nft,
        uint indexed tokenId,
        address indexed buyer,
        address seller,
        uint price
    );

    //空投事件
    event AirdropClaimed(
        address indexed nft,
        uint indexed tokenId,
        address indexed buyer,
        address seller,
        uint originalPrice,
        uint discounteredPrice
    );

    //错误定义
    error NotOwner();
    error InvalidPrice();
    error NotWhitelisted();
    error NotListed();
    error CannotBuyOwn();
    error InvalidPayment();
    error InsufficientFunds();
    error InvalidNonce();
    error PermitExpired();

    function list(uint tokenId, uint price) external {
        if (nft.ownerOf(tokenId) != msg.sender) {
            revert NotOwner();
        }

        if (price <= 0) {
            revert InvalidPrice();
        }

        nft.safeTransferFrom(msg.sender, address(this), tokenId);
        listings[tokenId] = Listing({seller: msg.sender, price: price});
        listedTokenIds.push(tokenId);
        tokenIdToIndex[tokenId] = listedTokenIds.length - 1;
        isListed[tokenId] = true;

        emit Listed(address(nft), tokenId, msg.sender, price);
    }

    function buyNFT(uint tokenId, uint price) external {
        Listing memory item = listings[tokenId];
        if (item.seller == address(0)) revert NotListed();
        if (msg.sender == item.seller) revert CannotBuyOwn();
        if (price != item.price) revert InvalidPayment();
        if (token.balanceOf(msg.sender) < item.price)
            revert InsufficientFunds();

        //支付
        bool success = token.transferFrom(
            msg.sender,
            address(this),
            item.price
        );
        require(success, "Token transferFrom failed");

        //转移NFT给买家
        nft.safeTransferFrom(address(this), msg.sender, tokenId);

        //清除上架信息
        _removeListing(tokenId);

        emit Bought(address(nft), tokenId, msg.sender, item.seller, item.price);
    }

    function permitPerPay(
        address owner,
        address spender,
        uint value,
        uint deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        if (deadline < block.timestamp) revert PermitExpired();
        IERC20Permit(address(token)).permit(
            owner,
            spender,
            value,
            deadline,
            v,
            r,
            s
        );
    }

    //通过merkle树验证白名单购买NFT
    function claimNFT(uint tokenId, bytes32[] memory proof) external {
        Listing memory item = listings[tokenId];
        if (item.seller == address(0)) revert NotListed();
        if (msg.sender == item.seller) revert CannotBuyOwn();

        //验证白名单并计算优惠价格
        uint discountedPrice = _verifyWhitelistAndCalculatePrice(
            msg.sender,
            tokenId,
            proof
        );
        if (token.balanceOf(msg.sender) < discountedPrice)
            revert InsufficientFunds();

        // 支付优惠价到market
        bool success = token.transferFrom(
            msg.sender,
            address(this),
            discountedPrice
        );
        require(success, "Token transferFrom failed");

        // 转移NFT给买家
        nft.safeTransferFrom(address(this), msg.sender, tokenId);

        //清除上架信息
        _removeListing(tokenId);

        emit AirdropClaimed(
            address(nft),
            tokenId,
            msg.sender,
            item.seller,
            item.price,
            discountedPrice
        );
    }

    //验证白名单，计算价格
    function _verifyWhitelistAndCalculatePrice(
        address user,
        uint tokenId,
        bytes32[] memory proof
    ) internal view returns (uint discountedPrice) {
        // 验证用户在白名单当中
        bytes32 leaf = keccak256(abi.encodePacked(user, tokenId));
        bool isValid = proof.verify(merkleRoot, leaf);
        if (isValid){
            // 计算优惠价格(50% 折扣)
            uint originalPrice = listings[tokenId].price;
            discountedPrice = calculateDiscountedPrice(originalPrice);
        }else{
            //不在白名单，以原价买入
            discountedPrice = listings[tokenId].price;
        }

        
    }

    function _removeListing(uint tokenId) internal {
        if (!isListed[tokenId]) return;
        uint index = tokenIdToIndex[tokenId];
        uint lastIdx = listedTokenIds.length - 1;

        if (index != lastIdx) {
            uint lastTokenId = listedTokenIds[lastIdx]; //最后一位置所对应的tokenId
            //当前位置替换为lastTokenId
            listedTokenIds[index] = lastTokenId;
            tokenIdToIndex[lastTokenId] = index;
        }

        //删除旧的数据
        listedTokenIds.pop();
        delete tokenIdToIndex[tokenId];
        delete isListed[tokenId];
        delete listings[tokenId];
    }

    //更新merkle树根
    function updateMerkleRoot(bytes32 _merkleRoot) external {
        merkleRoot = _merkleRoot;
    }

    //或者上架nft的数量
    function getListedTokenIdsLength() public view returns (uint) {
        return listedTokenIds.length;
    }

    //获取上架的NFT ID列表
    function getListedTokenIds() public view returns (uint[] memory) {
        return listedTokenIds;
    }

    function calculateDiscountedPrice(uint originalPrice) public pure returns(uint){
        return (originalPrice * (BPS_DENOMINATOR - DISCOUNT_BPS)) / BPS_DENOMINATOR;
    }

    /**
     * ERC721 接收器实现
     */
    function onERC721Received(
        address,
        address,
        uint,
        bytes calldata
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
