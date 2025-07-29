// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract MemeToken is ERC20, Ownable, ReentrancyGuard {
    uint256 public totalSupplyLimit;
    uint256 public perMint;
    uint256 public price;
    address public creator;
    address public factory;
    
    bool private initialized;
    
    // 存储动态名称和符号
    string private _tokenName;
    string private _tokenSymbol;
    
    error AlreadyInitialized();
    error NotInitialized();
    error ExceedsTotalSupply();
    error InsufficientPayment();
    error OnlyFactory();
    error OnlyCreator();
    
    event TokenInitialized(
        string name,
        string symbol,
        uint256 totalSupplyLimit,
        uint256 perMint,
        uint256 price,
        address creator
    );
    
    event TokensMinted(address indexed to, uint256 amount, uint256 cost);
    
    constructor() ERC20("", "") {
        // 构造函数不进行初始化，等待代理调用initialize
    }
    
    function initialize(
        string memory name_,
        string memory symbol_,
        uint256 totalSupplyLimit_,
        uint256 perMint_,
        uint256 price_,
        address factory_,
        address creator_
    ) external {
        if (initialized) revert AlreadyInitialized();
        
        // 设置动态名称和符号
        _tokenName = name_;
        _tokenSymbol = symbol_;
        totalSupplyLimit = totalSupplyLimit_;
        perMint = perMint_;
        price = price_;
        factory = factory_;
        creator = creator_;
        initialized = true;
        
        // 转移所有权给创建者
        _transferOwnership(creator_);
        
        emit TokenInitialized(name_, symbol_, totalSupplyLimit_, perMint_, price_, creator_);
    }
    
    function mint(address to) external nonReentrant {
        if (!initialized) revert NotInitialized();
        if (msg.sender != factory) revert OnlyFactory();
        if (totalSupply() + perMint > totalSupplyLimit) revert ExceedsTotalSupply();
        
        _mint(to, perMint);
        
        emit TokensMinted(to, perMint, price);
    }
    
    function getMintInfo() external view returns (
        uint256 totalSupply_,
        uint256 totalSupplyLimit_,
        uint256 perMint_,
        uint256 price_,
        address creator_
    ) {
        return (totalSupply(), totalSupplyLimit, perMint, price, creator);
    }
    
    function getRemainingSupply() external view returns (uint256) {
        return totalSupplyLimit - totalSupply();
    }
    
    function getMintCount() external view returns (uint256) {
        return totalSupplyLimit / perMint;
    }
    
    function getMintedCount() external view returns (uint256) {
        return totalSupply() / perMint;
    }
    
    // 重写name()和symbol()函数以支持动态设置
    function name() public view virtual override returns (string memory) {
        return _tokenName;
    }
    
    function symbol() public view virtual override returns (string memory) {
        return _tokenSymbol;
    }
}