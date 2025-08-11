// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// Uniswap V2 接口
interface IUniswapV2Pair {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
}

interface IUniswapV2Factory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

interface IUniswapV2Router {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
}

contract FlashSwapArbitrage is Ownable, ReentrancyGuard {
    IUniswapV2Factory public immutable factory;
    IUniswapV2Router public immutable routerA;
    IUniswapV2Router public immutable routerB;
    
    address public immutable WETH;
    
    struct ArbitrageParams {
        address tokenA;
        address tokenB;
        address pairA;  // 价格较低的池子
        address pairB;  // 价格较高的池子
        uint256 amountIn;
        bool isToken0;
    }
    
    event ArbitrageExecuted(
        address indexed tokenA,
        address indexed tokenB,
        uint256 amountBorrowed,
        uint256 profit
    );
    
    event FlashSwapInitiated(
        address indexed pair,
        address indexed token,
        uint256 amount
    );
    
    constructor(
        address _factory,
        address _routerA,
        address _routerB
    ) {
        factory = IUniswapV2Factory(_factory);
        routerA = IUniswapV2Router(_routerA);
        routerB = IUniswapV2Router(_routerB);
        WETH = routerA.WETH();
    }
    
    // 执行套利
    function executeArbitrage(
        address tokenA,
        address tokenB,
        uint256 amountIn
    ) external onlyOwner nonReentrant {
        // 获取两个池子的地址
        address pairA = factory.getPair(tokenA, tokenB);
        address pairB = factory.getPair(tokenA, tokenB); // 在实际中这应该是不同的factory
        
        require(pairA != address(0) && pairB != address(0), "Pair not exists");
        
        // 检查套利机会
        (bool profitable, uint256 profit) = checkArbitrage(tokenA, tokenB, amountIn);
        require(profitable, "No arbitrage opportunity");
        
        // 确定token0和token1的顺序
        IUniswapV2Pair pair = IUniswapV2Pair(pairA);
        address token0 = pair.token0();
        bool isToken0 = tokenA == token0;
        
        // 准备闪电兑换参数
        ArbitrageParams memory params = ArbitrageParams({
            tokenA: tokenA,
            tokenB: tokenB,
            pairA: pairA,
            pairB: pairB,
            amountIn: amountIn,
            isToken0: isToken0
        });
        
        // 编码参数
        bytes memory data = abi.encode(params);
        
        // 执行闪电兑换
        uint256 amount0Out = isToken0 ? amountIn : 0;
        uint256 amount1Out = isToken0 ? 0 : amountIn;
        
        emit FlashSwapInitiated(pairA, tokenA, amountIn);
        
        // 从pairA借出tokenA
        pair.swap(amount0Out, amount1Out, address(this), data);
        
        emit ArbitrageExecuted(tokenA, tokenB, amountIn, profit);
    }
    
    // Uniswap V2 回调函数
    function uniswapV2Call(
        address sender,
        uint amount0,
        uint amount1,
        bytes calldata data
    ) external {
        // 验证调用者是有效的pair合约
        ArbitrageParams memory params = abi.decode(data, (ArbitrageParams));
        require(msg.sender == params.pairA, "Invalid caller");
        require(sender == address(this), "Invalid sender");
        
        uint256 amountBorrowed = amount0 > 0 ? amount0 : amount1;
        
        // 步骤1: 用借来的tokenA在pairB中兑换tokenB
        IERC20(params.tokenA).approve(address(routerB), amountBorrowed);
        
        address[] memory path = new address[](2);
        path[0] = params.tokenA;
        path[1] = params.tokenB;
        
        uint[] memory amounts = routerB.swapExactTokensForTokens(
            amountBorrowed,
            0, // 接受任何数量的tokenB
            path,
            address(this),
            block.timestamp + 300
        );
        
        uint256 tokenBReceived = amounts[1];
        
        // 步骤2: 用tokenB在pairA中兑换回tokenA
        IERC20(params.tokenB).approve(address(routerA), tokenBReceived);
        
        path[0] = params.tokenB;
        path[1] = params.tokenA;
        
        amounts = routerA.swapExactTokensForTokens(
            tokenBReceived,
            0,
            path,
            address(this),
            block.timestamp + 300
        );
        
        uint256 tokenAReceived = amounts[1];
        
        // 步骤3: 计算需要还回的数量（借款 + 手续费）
        uint256 fee = (amountBorrowed * 3) / 1000; // 0.3% 手续费
        uint256 amountToRepay = amountBorrowed + fee;
        
        require(tokenAReceived >= amountToRepay, "Insufficient profit for repayment");
        
        // 步骤4: 还款给pair合约
        IERC20(params.tokenA).transfer(params.pairA, amountToRepay);
        
        // 步骤5: 剩余的就是利润
        uint256 profit = tokenAReceived - amountToRepay;
        if (profit > 0) {
            IERC20(params.tokenA).transfer(owner(), profit);
        }
    }
    
    // 检查套利机会
    function checkArbitrage(
        address tokenA,
        address tokenB,
        uint256 amountIn
    ) public view returns (bool profitable, uint256 profit) {
        address pairA = factory.getPair(tokenA, tokenB);
        address pairB = factory.getPair(tokenA, tokenB);
        
        if (pairA == address(0) || pairB == address(0)) {
            return (false, 0);
        }
        
        // 获取两个池子的储备量
        (uint112 reserveA0, uint112 reserveA1,) = IUniswapV2Pair(pairA).getReserves();
        (uint112 reserveB0, uint112 reserveB1,) = IUniswapV2Pair(pairB).getReserves();
        
        // 确定token顺序
        bool isToken0 = tokenA == IUniswapV2Pair(pairA).token0();
        
        uint256 reserveAIn = isToken0 ? reserveA0 : reserveA1;
        uint256 reserveAOut = isToken0 ? reserveA1 : reserveA0;
        uint256 reserveBIn = isToken0 ? reserveB1 : reserveB0;
        uint256 reserveBOut = isToken0 ? reserveB0 : reserveB1;
        
        // 计算在pairB中用tokenA换tokenB能得到多少
        uint256 tokenBFromPairB = routerB.getAmountOut(amountIn, reserveBIn, reserveBOut);
        
        // 计算用这些tokenB在pairA中能换回多少tokenA
        uint256 tokenAFromPairA = routerA.getAmountOut(tokenBFromPairB, reserveAOut, reserveAIn);
        
        // 计算手续费
        uint256 fee = (amountIn * 3) / 1000;
        uint256 totalCost = amountIn + fee;
        
        if (tokenAFromPairA > totalCost) {
            profitable = true;
            profit = tokenAFromPairA - totalCost;
        } else {
            profitable = false;
            profit = 0;
        }
    }
    
    // 紧急提取函数
    function emergencyWithdraw(address token) external onlyOwner {
        IERC20(token).transfer(owner(), IERC20(token).balanceOf(address(this)));
    }
    
    // 接收ETH
    receive() external payable {}
}