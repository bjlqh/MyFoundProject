// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IUniswapV2.sol";
import "./UniswapV2Factory.sol";

contract FlashSwapArbitrage is IUniswapV2Callee {
    address public owner;
    address public factoryA;  // 第一个factory
    address public factoryB;  // 第二个factory
    
    constructor(address _factoryA, address _factoryB) {
        owner = msg.sender;
        factoryA = _factoryA;
        factoryB = _factoryB;
    }
    
    event FlashSwapExecuted(
        address indexed poolA,
        address indexed poolB,
        address tokenA,
        address tokenB,
        uint256 amountBorrowed,
        uint256 profit
    );
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    // 执行闪电兑换套利
    function executeFlashSwap(
        address poolA,      // 价格较低的池子
        address poolB,      // 价格较高的池子
        address tokenA,     // 要借贷的代币
        address tokenB,     // 要交换的代币
        uint256 amountToBorrow  // 借贷数量
    ) external onlyOwner {
        require(poolA != address(0) && poolB != address(0), "Invalid pool addresses");
        
        // 从 poolA 开始闪电贷
        IUniswapV2PairSimple pair = IUniswapV2PairSimple(poolA);
        address token0 = pair.token0();
        address token1 = pair.token1();
        
        uint256 amount0Out = tokenA == token0 ? amountToBorrow : 0;
        uint256 amount1Out = tokenA == token1 ? amountToBorrow : 0;
        
        // 编码数据传递给回调函数
        bytes memory data = abi.encode(poolB, tokenA, tokenB, amountToBorrow);
        
        // 执行闪电贷
        pair.swap(amount0Out, amount1Out, address(this), data);
    }
    
    // Uniswap V2 回调函数
    function uniswapV2Call(
        address sender,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external override {
        // 验证调用者是合法的配对合约
        address token0 = IUniswapV2PairSimple(msg.sender).token0();
        address token1 = IUniswapV2PairSimple(msg.sender).token1();
        
        // 检查是否来自任一factory
        address pairA = IUniswapV2FactorySimple(factoryA).getPair(token0, token1);
        address pairB = IUniswapV2FactorySimple(factoryB).getPair(token0, token1);
        require(msg.sender == pairA || msg.sender == pairB, "Invalid pair");
        require(sender == address(this), "Invalid sender");
        
        // 解码数据
        (address poolB, address tokenA, address tokenB, uint256 amountBorrowed) = 
            abi.decode(data, (address, address, address, uint256));
        
        // 获取借到的代币数量
        uint256 amountReceived = amount0 > 0 ? amount0 : amount1;
        
        // 在 poolB 中将 tokenA 兑换为 tokenB
        uint256 amountOut = _swapOnPool(poolB, tokenA, tokenB, amountReceived);
        
        // 计算需要还款的数量（包含手续费 0.3%）
        uint256 amountToRepay = amountBorrowed * 1000 / 997 + 1;
        
        // 计算在poolA中用tokenB换回tokenA需要多少tokenB
        uint256 amountBNeeded = _calculateAmountIn(msg.sender, tokenB, tokenA, amountToRepay);
        
        // 确保有足够的tokenB
        require(amountOut >= amountBNeeded, "Insufficient tokenB for repayment");
        
        // 在poolA中用tokenB换回tokenA来偿还
        IERC20(tokenB).transfer(msg.sender, amountBNeeded);
        
        // 计算利润（剩余的tokenB）
        uint256 profit = amountOut - amountBNeeded;
        
        // 将利润转给owner
        if (profit > 0) {
            IERC20(tokenB).transfer(owner, profit);
        }
        
        emit FlashSwapExecuted(msg.sender, poolB, tokenA, tokenB, amountBorrowed, profit);
    }
    
    // 在指定池子中执行交换
    function _swapOnPool(
        address pool,
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) internal returns (uint256 amountOut) {
        IUniswapV2PairSimple pair = IUniswapV2PairSimple(pool);
        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        
        address token0 = pair.token0();
        bool token0IsTokenIn = tokenIn == token0;
        
        (uint112 reserveIn, uint112 reserveOut) = token0IsTokenIn ? 
            (reserve0, reserve1) : (reserve1, reserve0);
        
        // 计算输出数量 (考虑0.3%手续费)
        amountOut = getAmountOut(amountIn, reserveIn, reserveOut);
        
        // 转移代币到配对合约
        IERC20(tokenIn).transfer(pool, amountIn);
        
        // 执行交换
        (uint256 amount0Out, uint256 amount1Out) = token0IsTokenIn ? 
            (uint256(0), amountOut) : (amountOut, uint256(0));
        
        pair.swap(amount0Out, amount1Out, address(this), new bytes(0));
    }
    
    // 计算需要的输入数量
    function _calculateAmountIn(
        address pool,
        address tokenIn,
        address tokenOut,
        uint256 amountOutNeeded
    ) internal view returns (uint256 amountIn) {
        IUniswapV2PairSimple pair = IUniswapV2PairSimple(pool);
        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        
        address token0 = pair.token0();
        bool token0IsTokenIn = tokenIn == token0;
        
        (uint112 reserveIn, uint112 reserveOut) = token0IsTokenIn ? 
            (reserve0, reserve1) : (reserve1, reserve0);
        
        amountIn = getAmountIn(amountOutNeeded, reserveIn, reserveOut);
    }
    
    // Uniswap V2 公式：计算输出数量
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut)
        internal pure returns (uint amountOut)
    {
        require(amountIn > 0, 'INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'INSUFFICIENT_LIQUIDITY');
        uint amountInWithFee = amountIn * 997;
        uint numerator = amountInWithFee * reserveOut;
        uint denominator = reserveIn * 1000 + amountInWithFee;
        amountOut = numerator / denominator;
    }
    
    // Uniswap V2 公式：计算输入数量
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut)
        internal pure returns (uint amountIn)
    {
        require(amountOut > 0, 'INSUFFICIENT_OUTPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'INSUFFICIENT_LIQUIDITY');
        uint numerator = reserveIn * amountOut * 1000;
        uint denominator = (reserveOut - amountOut) * 997;
        amountIn = (numerator / denominator) + 1;
    }
    
    // 紧急提取函数
    function emergencyWithdraw(address token) external onlyOwner {
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance > 0) {
            IERC20(token).transfer(owner, balance);
        }
    }
}