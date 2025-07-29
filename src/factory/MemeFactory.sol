// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./MemeToken.sol";

contract MemeFactory is Ownable {
    MemeToken public immutable memeTokenImpl;

    mapping(address => address[]) public creatorTokens;
    mapping(address => bool) public isMemeToken;

    event MemeDeployed(
        address indexed token,
        address indexed creator,
        string symbol,
        uint256 totalSupply,
        uint256 perMint,
        uint256 price
    );

    event MemeMinted(
        address indexed token,
        address indexed buyer,
        uint256 cost,
        uint256 creatorShare,
        uint256 platformShare
    );

    error InvalidParameters();
    error TokenNotExists();
    error InsufficientPayment();

    constructor() {
        // 创建实现合约作为模板
        memeTokenImpl = new MemeToken();
    }

    function deployMeme(
        string memory symbol,
        uint256 totalSupplyLimit,
        uint256 perMint,
        uint256 price
    ) external returns (address token) {
        if (totalSupplyLimit == 0 || perMint == 0 || price == 0) {
            revert InvalidParameters();
        }
        if (totalSupplyLimit % perMint != 0) {
            revert InvalidParameters();
        }

        // 使用最小代理模式创建新合约
        token = Clones.clone(address(memeTokenImpl));
        
        // 通过代理调用初始化函数
        MemeToken(token).initialize(
            string.concat("MEME", symbol),  // 名称
            symbol,                         // 符号
            totalSupplyLimit,
            perMint,
            price,
            address(this),
            msg.sender
        );

        // 记录信息
        creatorTokens[msg.sender].push(token);
        isMemeToken[token] = true;

        emit MemeDeployed(
            token,
            msg.sender,
            symbol,
            totalSupplyLimit,
            perMint,
            price
        );
    }

    function mintMeme(address tokenAddr) external payable {
        if (!isMemeToken[tokenAddr]) revert TokenNotExists();

        MemeToken token = MemeToken(tokenAddr);
        (, , , uint256 price, ) = token.getMintInfo();

        // 检查支付金额是否足够
        if (msg.value < price) {
            revert InsufficientPayment();
        }

        // 计算费用分配
        uint256 platformShare = price / 100; // 平台分1%
        uint256 creatorShare = price - platformShare; // 创建者分99%

        // 先分配收益
        address creator = token.creator();
        (bool success1, ) = creator.call{value: creatorShare}(""); // 显式指定gas
        require(success1, "Failed to send creator share");

        (bool success2, ) = owner().call{value: platformShare}(""); // 同理
        require(success2, "Failed to send platform share");

        // 然后铸币（不需要发送ETH，因为费用已经在工厂合约中处理了）
        token.mint(msg.sender);

        emit MemeMinted(address(token), msg.sender, price, creatorShare, platformShare);
    }

    function getCreatorTokens(
        address creator
    ) external view returns (address[] memory) {
        return creatorTokens[creator];
    }

    function getMemeInfo(
        address tokenAddr
    )
        external
        view
        returns (
            uint256 totalSupply,
            uint256 totalSupplyLimit,
            uint256 perMint,
            uint256 price,
            address creator
        )
    {
        if (!isMemeToken[tokenAddr]) {
            revert TokenNotExists();
        }
        return MemeToken(tokenAddr).getMintInfo();
    }
}
