// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract LaunchPadToken is ERC20, Ownable, ReentrancyGuard {
    
    uint public totalSupplyLimit;
    uint public perMint;
    uint public price;
    address public creator;
    address public launchPad;

    bool private initialized;

    string private _tokenName;
    string private _tokenSymbol;

    event TokenInitialized(
        string name,
        string symbol,
        uint256 totalSupplyLimit,
        uint256 perMint,
        uint256 price,
        address creator
    );
    
    event TokensMinted(address indexed to, uint256 amount, uint256 cost);
    event LiquidityTokensMinted(address indexed to, uint256 amount);
    

    error AlreadyInitialized();
    error NotInitialized();
    error ExceedsTotalSupply();
    error InsufficientPayment();
    error OnlyCreator();
    error OnlyLaunchPad();

    //因为要使用最小代理，所以构造函数不能进行初始化，需要在initialize中进行初始化，等待创建代理之后调用initialize
    constructor() ERC20("", "") {}

    function initialize(
        string memory name,
        string memory symbol,
        uint256 totalSupplyLimit_,
        uint256 perMint_,
        uint256 price_,
        address launchPad_,
        address creator_
    ) external {
        if (initialized) revert AlreadyInitialized();

        _tokenName = name;
        _tokenSymbol = symbol;
        totalSupplyLimit = totalSupplyLimit_;
        perMint = perMint_;
        price = price_;
        launchPad = launchPad_;
        creator = creator_;
        initialized = true;

        // 转移所有权给创建者
        _transferOwnership(creator_);

        emit TokenInitialized(
            name,
            symbol,
            totalSupplyLimit_,
            perMint_,
            price_,
            creator_
        );
    }

    function mint(address to) external nonReentrant {
        //需要由最小代理初始化
        if(!initialized){
            revert NotInitialized();
        }
        //只有工厂合约可以调用
        if(msg.sender != launchPad){
            revert OnlyLaunchPad();
        }
        //不能超过总供应量
        if(totalSupply() + perMint > totalSupplyLimit){
            revert ExceedsTotalSupply();
        }
        _mint(to, perMint);

        emit TokensMinted(to, perMint, price);
    }

    //为流动性铸造代币，这里不受totalSupplyLimit限制,流动性部分为:totalSupplyLimit + 额外5%
    function mintForLiquidity(address to, uint amount) external nonReentrant{
        if (!initialized) revert NotInitialized();
        if (msg.sender != launchPad) revert OnlyLaunchPad();
        _mint(to, amount);
        emit LiquidityTokensMinted(to, amount);
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

    function isMintingComplete() external view returns (bool) {
        return totalSupply() >= totalSupplyLimit;
    }
}
