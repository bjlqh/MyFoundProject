# LaunchPadFactory
## 问题
1. 这个接口IUniswapV2Router的作用是什么？   
是与UniswapV2 去中心化交易所交互的桥梁。
核心功能：addLiquidityETH() 用于向Uniswap添加代币/ETH流动性对。
- 输入参数：
  - token：要添加流动性的代币合约地址
  - amountTokenDesired： desired 是期望添加的代币数量
  - amountTokenMin：min 是接受的最小代币数量
  - amountETHMin：min 是接受的最小ETH数量
  - to：接收流动性代币的地址
  - deadline：交易过期时间戳

2.ReentrancyGuard的作用是什么，怎么使用的？     
是OpenZeppelin提供的重入攻击防护机制：
- 防护原理 ：通过状态变量跟踪函数执行状态，防止函数在执行过程中被递归调用。
- 使用方式 ：在 `buyToken` 函数上添加 nonReentrant 修饰符
- 防护场景 ：防止恶意合约在ETH转账过程中重新调用 buyToken 函数，避免重复购买或资金损失

3._addLiquidity。逐行解释一下这个代码