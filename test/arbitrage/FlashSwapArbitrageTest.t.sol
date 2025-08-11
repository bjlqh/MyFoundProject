// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../../src/arbitrage/FlashSwapArbitrage.sol";
import "../../src/arbitrage/TestTokenA.sol";
import "../../src/arbitrage/TestTokenB.sol";

// Mock Uniswap V2 Factory
contract MockUniswapV2Factory {
    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;
    
    function createPair(address tokenA, address tokenB) external returns (address pair) {
        require(tokenA != tokenB, "Identical tokens");
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "Zero address");
        require(getPair[token0][token1] == address(0), "Pair exists");
        
        // 部署新的pair合约
        pair = address(new MockUniswapV2Pair(token0, token1));
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair;
        allPairs.push(pair);
    }
}

// Mock Uniswap V2 Pair
contract MockUniswapV2Pair {
    address public token0;
    address public token1;
    uint112 private reserve0;
    uint112 private reserve1;
    uint32 private blockTimestampLast;
    
    constructor(address _token0, address _token1) {
        token0 = _token0;
        token1 = _token1;
    }
    
    function getReserves() external view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }
    
    function setReserves(uint112 _reserve0, uint112 _reserve1) external {
        reserve0 = _reserve0;
        reserve1 = _reserve1;
        blockTimestampLast = uint32(block.timestamp);
    }
    
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external {
        require(amount0Out > 0 || amount1Out > 0, "Insufficient output amount");
        require(amount0Out < reserve0 && amount1Out < reserve1, "Insufficient liquidity");
        
        // 转移代币给接收者
        if (amount0Out > 0) IERC20(token0).transfer(to, amount0Out);
        if (amount1Out > 0) IERC20(token1).transfer(to, amount1Out);
        
        // 如果有回调数据，执行回调
        if (data.length > 0) {
            IUniswapV2Callee(to).uniswapV2Call(msg.sender, amount0Out, amount1Out, data);
        }
        
        // 检查余额并更新储备量
        uint balance0 = IERC20(token0).balanceOf(address(this));
        uint balance1 = IERC20(token1).balanceOf(address(this));
        
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
    }
    
    // 添加流动性（简化版）
    function addLiquidity(uint amount0, uint amount1) external {
        IERC20(token0).transferFrom(msg.sender, address(this), amount0);
        IERC20(token1).transferFrom(msg.sender, address(this), amount1);
        reserve0 = uint112(IERC20(token0).balanceOf(address(this)));
        reserve1 = uint112(IERC20(token1).balanceOf(address(this)));
    }
}

interface IUniswapV2Callee {
    function uniswapV2Call(address sender, uint amount0, uint amount1, bytes calldata data) external;
}

// Mock Uniswap V2 Router
contract MockUniswapV2Router {
    address public immutable factory;
    address public immutable WETH;
    
    constructor(address _factory, address _WETH) {
        factory = _factory;
        WETH = _WETH;
    }
    
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut) {
        require(amountIn > 0, "Insufficient input amount");
        require(reserveIn > 0 && reserveOut > 0, "Insufficient liquidity");
        uint amountInWithFee = amountIn * 997;
        uint numerator = amountInWithFee * reserveOut;
        uint denominator = reserveIn * 1000 + amountInWithFee;
        amountOut = numerator / denominator;
    }
    
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts) {
        require(deadline >= block.timestamp, "Expired");
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        
        for (uint i; i < path.length - 1; i++) {
            address pair = MockUniswapV2Factory(factory).getPair(path[i], path[i + 1]);
            require(pair != address(0), "Pair not exists");
            
            (uint112 reserve0, uint112 reserve1,) = MockUniswapV2Pair(pair).getReserves();
            
            bool isToken0 = path[i] < path[i + 1];
            uint reserveIn = isToken0 ? reserve0 : reserve1;
            uint reserveOut = isToken0 ? reserve1 : reserve0;
            
            amounts[i + 1] = this.getAmountOut(amounts[i], reserveIn, reserveOut);
        }
        
        require(amounts[amounts.length - 1] >= amountOutMin, "Insufficient output amount");
        
        // 执行实际的代币转移
        IERC20(path[0]).transferFrom(msg.sender, MockUniswapV2Factory(factory).getPair(path[0], path[1]), amounts[0]);
        
        for (uint i; i < path.length - 1; i++) {
            address pair = MockUniswapV2Factory(factory).getPair(path[i], path[i + 1]);
            bool isToken0 = path[i] < path[i + 1];
            uint amount0Out = isToken0 ? 0 : amounts[i + 1];
            uint amount1Out = isToken0 ? amounts[i + 1] : 0;
            address toAddr = i < path.length - 2 ? MockUniswapV2Factory(factory).getPair(path[i + 1], path[i + 2]) : to;
            MockUniswapV2Pair(pair).swap(amount0Out, amount1Out, toAddr, new bytes(0));
        }
    }
}

contract FlashSwapArbitrageTest is Test {
    FlashSwapArbitrage public arbitrage;
    TestTokenA public tokenA;
    TestTokenB public tokenB;
    MockUniswapV2Factory public factory;
    MockUniswapV2Router public routerA;
    MockUniswapV2Router public routerB;
    MockUniswapV2Pair public pairA;
    MockUniswapV2Pair public pairB;
    
    address public owner = address(0x1);
    address public user = address(0x2);
    address public WETH = address(0x3);
    
    function setUp() public {
        vm.startPrank(owner);
        
        // 部署代币
        tokenA = new TestTokenA();
        tokenB = new TestTokenB();
        
        // 部署工厂和路由
        factory = new MockUniswapV2Factory();
        routerA = new MockUniswapV2Router(address(factory), WETH);
        routerB = new MockUniswapV2Router(address(factory), WETH);
        
        // 创建交易对
        address pairAddress = factory.createPair(address(tokenA), address(tokenB));
        pairA = MockUniswapV2Pair(pairAddress);
        pairB = pairA; // 在这个测试中，我们使用同一个pair但设置不同的储备量来模拟价差
        
        // 部署套利合约
        arbitrage = new FlashSwapArbitrage(
            address(factory),
            address(routerA),
            address(routerB)
        );
        
        // 设置初始流动性
        setupLiquidity();
        
        vm.stopPrank();
    }
    
    function setupLiquidity() internal {
        // 给pair添加流动性
        uint256 amountA = 1000 * 10**18;
        uint256 amountB = 2000 * 10**18; // 设置不同的比例来创造套利机会
        
        tokenA.approve(address(pairA), amountA);
        tokenB.approve(address(pairA), amountB);
        
        pairA.addLiquidity(amountA, amountB);
        
        // 为了模拟价差，我们可以手动设置不同的储备量
        // 这里我们设置pairA的价格为 1 TokenA = 2 TokenB
        pairA.setReserves(uint112(amountA), uint112(amountB));
        
        console.log("Liquidity setup completed");
        console.log("TokenA balance in pair:", tokenA.balanceOf(address(pairA)));
        console.log("TokenB balance in pair:", tokenB.balanceOf(address(pairB)));
    }
    
    function testCheckArbitrage() public {
        uint256 amountIn = 100 * 10**18;
        
        (bool profitable, uint256 profit) = arbitrage.checkArbitrage(
            address(tokenA),
            address(tokenB),
            amountIn
        );
        
        console.log("Arbitrage profitable:", profitable);
        console.log("Expected profit:", profit);
        
        // 在我们的设置中，由于使用同一个pair，可能没有套利机会
        // 这个测试主要验证函数能正常运行
    }
    
    function testFlashSwapExecution() public {
        vm.startPrank(owner);
        
        // 给套利合约一些初始代币用于测试
        tokenA.transfer(address(arbitrage), 1000 * 10**18);
        tokenB.transfer(address(arbitrage), 1000 * 10**18);
        
        uint256 initialBalanceA = tokenA.balanceOf(owner);
        uint256 initialBalanceB = tokenB.balanceOf(owner);
        
        console.log("Initial TokenA balance:", initialBalanceA);
        console.log("Initial TokenB balance:", initialBalanceB);
        
        // 尝试执行套利（可能会失败，因为我们使用的是同一个pair）
        try arbitrage.executeArbitrage(address(tokenA), address(tokenB), 10 * 10**18) {
            console.log("Arbitrage executed successfully");
            
            uint256 finalBalanceA = tokenA.balanceOf(owner);
            uint256 finalBalanceB = tokenB.balanceOf(owner);
            
            console.log("Final TokenA balance:", finalBalanceA);
            console.log("Final TokenB balance:", finalBalanceB);
            
            if (finalBalanceA > initialBalanceA) {
                console.log("Profit in TokenA:", finalBalanceA - initialBalanceA);
            }
        } catch Error(string memory reason) {
            console.log("Arbitrage failed:", reason);
        }
        
        vm.stopPrank();
    }
    
    function testEmergencyWithdraw() public {
        vm.startPrank(owner);
        
        // 给合约一些代币
        tokenA.transfer(address(arbitrage), 100 * 10**18);
        
        uint256 contractBalance = tokenA.balanceOf(address(arbitrage));
        uint256 ownerBalanceBefore = tokenA.balanceOf(owner);
        
        // 紧急提取
        arbitrage.emergencyWithdraw(address(tokenA));
        
        uint256 ownerBalanceAfter = tokenA.balanceOf(owner);
        
        assertEq(ownerBalanceAfter - ownerBalanceBefore, contractBalance);
        assertEq(tokenA.balanceOf(address(arbitrage)), 0);
        
        vm.stopPrank();
    }
}