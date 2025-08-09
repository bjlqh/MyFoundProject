// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./LaunchPadToken.sol";

/**
 * 路由合约接口
 * 核心职责：用户交互层
 * 路径计算：计算最优交易路径和价格
 * 安全包装：提供安全的交易执行环境
 */
interface IUniswapV2Router {
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    )
        external
        payable
        returns (uint amountToken, uint amountETH, uint liquidity);

    //查询卖出代币可以得到多少ETH
    function getAmountsOut(
        uint amountIn,
        address[] calldata path     //交易路径[tokenA, tokenB]表示从TokenA换到TokenB
    ) external view returns (uint[] memory amounts);//amounts[0] = 输入代币数量, amounts[1] = 输出代币数量

    //返回WrappedETH的合约地址
    function WETH() external pure returns (address);

    //用ETH购买代币
    function swapExactETHForTokens(
        uint amountOutMin,
        address[] calldata path,        //对于ETH换代币，[WETH,Token]
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts);     //返回实际交换的数量数组。amounts[0]实际消耗的ETH数量，amounts[1]实际获得的代币数量
}

/**
 * 工厂合约接口
 * 核心职责：交易对管理
 * 创建交易对，获取交易对。使用create2实现确定性地址生成
 */
interface IUniswapV2Factory {
    //返回两个给定代币的流动性对合约地址
    function getPair(
        address tokenA,
        address tokenB
    ) external view returns (address pair);
}

/**
 * 交易对合约接口
 * 核心职责：流动性池操作
 * 维护两种代币的储备量，代币交换，流动性添加，流动性移除
 */
interface IUniswapV2Pair {

    //获取流动性池中两种代币的储备量信息
    function getReserves()
        external
        view
        returns (uint reserve0, uint reserve1, uint blockTimestampLast);//blockTimestampLast:最后一次更新储备量的区块时间戳


    function token0() external view returns (address);

    function token1() external view returns (address);
}

contract LaunchPadFactory is Ownable, ReentrancyGuard {
    LaunchPadToken public immutable tokenImpl;
    IUniswapV2Router public immutable uniswapRouter;

    mapping(address => bool) public isValidToken;
    mapping(address => bool) public liquidityAdded;

    mapping(address => address[]) public creatorTokens;
    mapping(address => bool) public isLaunchPadToken;

    uint public constant PLATFORM_FEE = 5; // 5%
    uint public constant LIQUIDITY_PERCENTAGE = 20; // 20%的收益作为流动性资金添加到Uniswap

    constructor(address _router) {
        tokenImpl = new LaunchPadToken();
        uniswapRouter = IUniswapV2Router(_router);
    }

    event TokenContractCreated(
        address indexed token,
        address indexed creator,
        string symbol
    );
    event TokenMinted(
        address indexed token,
        address indexed buyer,
        uint amount
    );
    event LiquidityAdded(
        address indexed token,
        uint tokenAmount,
        uint ethAmount
    );
    event TokenDeployed(
        address indexed token,
        address indexed creator,
        string symbol,
        uint256 totalSupply,
        uint256 perMint,
        uint256 price
    );
    event TokenBoughtFromUniswap(
        address indexed token,
        address indexed buyer,
        uint256 ethAmount,
        uint256 tokenAmount
    );

    error TokenNotExists();
    error NoLiquidityAvailable();
    error PriceNotFavorable();
    error InvalidToken();
    error InvalidParameters();

    //创建代币
    function createToken(
        string memory symbol,
        uint totalSupply,
        uint mintAmount,
        uint price
    ) external returns (address) {
        require(
            totalSupply > 0 && mintAmount > 0 && price > 0,
            "Invalid params"
        );
        address token = Clones.clone(address(tokenImpl));
        LaunchPadToken(token).initialize(
            string.concat("LP", symbol),
            symbol,
            totalSupply,
            mintAmount,
            price,
            address(this),
            msg.sender
        );
        isValidToken[token] = true;
        emit TokenContractCreated(token, msg.sender, symbol);
        return token;
    }

    //购买代币
    function buyToken(address token) external payable nonReentrant {
        require(isValidToken[token], "Token not exist");
        LaunchPadToken tokenContract = LaunchPadToken(token);
        (, , , uint256 price, ) = tokenContract.getMintInfo();
        require(msg.value >= price, "Insufficient payment");

        uint liquidityETH = (price * LIQUIDITY_PERCENTAGE) / 100;
        //分配费用 5%给平台，95%给创建者
        uint platformFee = (price * PLATFORM_FEE) / 100;
        uint creatorFee = price - platformFee - liquidityETH;

        (bool success1, ) = tokenContract.creator().call{value: creatorFee}("");
        require(success1, "Creator transfer failed");

        (bool success2, ) = owner().call{value: platformFee}("");
        require(success2, "Platform transfer failed");

        //铸造
        tokenContract.mint(msg.sender);

        //如果达到总供应量，添加流动性
        if (tokenContract.totalSupply() == tokenContract.totalSupplyLimit()) {
            _addLiquidity(token);
        }

        emit TokenMinted(token, msg.sender, tokenContract.perMint());
    }

    //内部函数：增加流动性
    function _addLiquidity(address token) internal {
        if (liquidityAdded[token]) return;
        LaunchPadToken tokenContract = LaunchPadToken(token);
        uint liquidityTokens = (tokenContract.totalSupplyLimit() *
            PLATFORM_FEE) / 100;
        uint liquidityETH = address(this).balance;

        if (liquidityETH > 0) {
            // 先铸造流动性代币
            tokenContract.mintForLiquidity(address(this), liquidityTokens);
            // 授权Uniswap合约使用流动性代币
            tokenContract.approve(address(uniswapRouter), liquidityTokens);
            // 添加流动性
            uniswapRouter.addLiquidityETH{value: liquidityETH}(
                token,
                liquidityTokens,
                0, // 接受任何数量的代币
                0, // 接受任何数量的ETH
                owner(),
                block.timestamp + 300
            );

            liquidityAdded[token] = true;
            emit LiquidityAdded(token, liquidityTokens, liquidityETH);
        }
    }

    //购买Meme币，-当Uniswap价格优于设定价格时使用
    function buyMeme(address token) external payable nonReentrant {
        if (!isValidToken[token]) revert InvalidToken();
        if (!liquidityAdded[token]) revert NoLiquidityAvailable();

        LaunchPadToken tokenContract = LaunchPadToken(token);
        (, , uint perMint, uint mintPrice, ) = tokenContract.getMintInfo();

        //获取当前Uniswap当前价格
        uint uniswapPrice = _getUniswapPrice(token, perMint);

        //检查Uniswap价格是优于mint价格(更便宜)
        if (uniswapPrice >= mintPrice) {
            revert PriceNotFavorable();
        }

        // 通过Uniswap购买代币
        address[] memory path = new address[](2);
        path[0] = uniswapRouter.WETH();
        path[1] = token;

        // 执行交换
        uint[] memory amounts = uniswapRouter.swapExactETHForTokens{
            value: msg.value
        }(0, path, msg.sender, block.timestamp + 300);

        emit TokenBoughtFromUniswap(token, msg.sender, msg.value, amounts[1]);
    }

    function _getUniswapPrice(
        address token,
        uint tokenAmount
    ) internal view returns (uint) {
        address[] memory path = new address[](2);
        path[0] = token;
        path[1] = uniswapRouter.WETH();

        try uniswapRouter.getAmountsOut(tokenAmount, path) returns (
            uint[] memory amounts
        ) {
            return amounts[1]; // 返回需要的ETH数量
        } catch {
            return type(uint).max; // 如果获取失败，返回最大值表示价格不优
        }
    }

    //检查代币是否有Uniswap流动性
    function hashUniswapLiquidity(address token) external view returns (bool){
        return liquidityAdded[token];
    }

    // 获取代币在Uniswap的当前价格(每个perMint需要多少ETH)
    function getUniswapPrice(address token) external view returns(uint){
        require(isValidToken[token], "Token not exist");
        if(!liquidityAdded[token]) return 0;

        LaunchPadToken tokenContract = LaunchPadToken(token);
        (, , uint256 perMint, , ) = tokenContract.getMintInfo();
        return _getUniswapPrice(token, perMint);
    }

    function deployToken(
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
        token = Clones.clone(address(tokenImpl));

        // 初始化代理合约
        LaunchPadToken(token).initialize(
            string.concat("LaunchPad", symbol),
            symbol,
            totalSupplyLimit,
            perMint,
            price,
            address(this),
            msg.sender
        );

        // 记录信息
        creatorTokens[msg.sender].push(token);
        isLaunchPadToken[token] = true;

        emit TokenDeployed(
            token,
            msg.sender,
            symbol,
            totalSupplyLimit,
            perMint,
            price
        );
    }

    function getTokenInfo(
        address token
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
        require(isValidToken[token], "Token not exist");
        return LaunchPadToken(token).getMintInfo();
    }

    receive() external payable {}
}
