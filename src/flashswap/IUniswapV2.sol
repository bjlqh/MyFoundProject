// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
 * @notice 定义了与Uniswap V2协议交互所需的核心接口。
 */

/**
 * @title 简化版的ERC20接口
 * @notice 只包含了最基本的函数
 */
interface IERC20Simple {
    function balanceOf(address owner) external view returns (uint);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);
    function approve(address spender, uint value) external returns (bool);
}

/**
 * @title 交易对合约的简化接口
 * @notice 包含流动性的核心功能
 */
interface IUniswapV2PairSimple {
    function initialize(address, address) external;
    function token0() external view returns (address);
    function token1() external view returns (address);
    // 核心交换功能，支持闪电兑换
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    // 获取流动性储备量
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function mint(address to) external returns (uint liquidity);
}

/**
 * @title UniswapV2Factory合约的简化工厂
 * @notice 用于管理交易对
 */
interface IUniswapV2FactorySimple {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

/**
 * @title 闪电兑换回调接口
 */
interface IUniswapV2Callee {
    /**
     * @notice 闪电兑换回调函数,当调用swap()函数并传入data参数时会触发此回调
     * @param sender 调用者地址
     * @param amount0 输入的token0数量
     * @param amount1 输入的token1数量
     * @param data 额外数据
     */
    function uniswapV2Call(address sender, uint amount0, uint amount1, bytes calldata data) external;
} 