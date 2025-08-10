# EIP-7702 TokenBank 实践指南

本项目实现了 EIP-7702 账户抽象功能，允许 EOA 账户委托给智能合约，实现批量操作和更好的用户体验。

## 🎯 项目目标

1. 部署支持批量执行的 Delegate 合约到 Sepolia
2. 修改 TokenBank 前端页面，支持 EOA 账户授权给 Delegate 合约
3. 在一个交易中完成授权和存款操作

## 📁 项目结构

```
├── src/
│   ├── EIP7702Delegate.sol          # EIP-7702 委托合约
│   ├── bank/TokenBank.sol            # TokenBank 合约
│   └── MyToken.sol                   # ERC20 代币合约
├── script/
│   └── DeployEIP7702DelegateScript.s.sol  # 部署脚本
├── test/
│   └── EIP7702DelegateTest.t.sol     # 测试文件
└── frontend/
    ├── index.html                    # 前端页面
    └── app.js                        # JavaScript 逻辑
```

## 🔧 合约功能

### EIP7702Delegate 合约

- **批量操作支持**: 支持在一个交易中执行多个操作
- **操作类型**:
  - `APPROVE_TOKEN`: 授权代币
  - `DEPOSIT_TO_BANK`: 存款到银行
  - `PERMIT2_APPROVE`: Permit2 授权
  - `PERMIT2_DEPOSIT`: Permit2 存款

- **主要方法**:
  - `approveAndDeposit()`: 授权并存款的组合操作
  - `permit2ApproveAndDeposit()`: 使用 Permit2 的授权并存款
  - `executeBatch()`: 批量执行操作
  - `executeOperation()`: 执行单个操作

## 🚀 部署指南

### 1. 环境准备

```bash
# 安装依赖
forge install

# 设置环境变量
export PRIVATE_KEY="your_private_key_here"
export ETHERSCAN_API_KEY="your_etherscan_api_key_here"
```

### 2. 运行测试

```bash
# 运行 EIP7702Delegate 测试
forge test --match-contract EIP7702DelegateTest -v

# 运行所有测试
forge test
```

### 3. 部署到 Sepolia

```bash
# 部署 EIP7702Delegate 合约
forge script script/DeployEIP7702DelegateScript.s.sol \
  --rpc-url sepolia \
  --broadcast \
  --verify

# 如果需要，先部署 TokenBank 和 MyToken
forge script script/DeployEIP712Script.s.sol \
  --rpc-url sepolia \
  --broadcast \
  --verify
```

### 4. 获取测试 ETH

在部署前，确保您的账户有足够的 Sepolia ETH：
- [Sepolia Faucet 1](https://sepoliafaucet.com/)
- [Sepolia Faucet 2](https://www.alchemy.com/faucets/ethereum-sepolia)
- [Chainlink Faucet](https://faucets.chain.link/sepolia)

## 🌐 前端使用指南

### 1. 启动前端

```bash
# 进入前端目录
cd frontend

# 使用简单的 HTTP 服务器
python3 -m http.server 8000
# 或者使用 Node.js
npx serve .
```

### 2. 连接钱包

1. 打开 `http://localhost:8000`
2. 点击 "连接 MetaMask"
3. 确保切换到 Sepolia 测试网络

### 3. 配置合约地址

在前端页面中填入以下合约地址：
- **Token 合约地址**: 部署的 MyToken 合约地址
- **TokenBank 合约地址**: 部署的 TokenBank 合约地址
- **EIP7702Delegate 合约地址**: 部署的 EIP7702Delegate 合约地址
- **Permit2 合约地址**: `0x000000000022D473030F116dDEE9F6B43aC78BA3` (官方地址)

### 4. 执行操作

#### 单步操作
- **授权并存款**: 在一个交易中完成代币授权和存款
- **Permit2 授权并存款**: 使用 Permit2 标准的授权和存款

#### 批量操作
- 选择操作类型和金额
- 点击 "执行批量操作" 在一个交易中完成多个步骤

#### EIP-7702 委托 (实验性)
- 点击 "委托账户" 体验 EIP-7702 概念
- **注意**: 这是演示功能，实际的 EIP-7702 需要以太坊客户端支持

## 🔍 技术特性

### EIP-7702 账户抽象

- **临时委托**: EOA 账户可以临时委托给智能合约
- **批量执行**: 在一个交易中执行多个操作
- **Gas 优化**: 减少交易数量，降低 Gas 成本
- **用户体验**: 简化复杂的 DeFi 操作流程

### 安全特性

- **权限控制**: 只有授权的操作才能执行
- **紧急提取**: 支持紧急情况下的资产恢复
- **操作验证**: 每个操作都有严格的验证逻辑

## 📊 测试结果

所有测试均已通过：

```
Ran 10 tests for test/EIP7702DelegateTest.t.sol:EIP7702DelegateTest
[PASS] testApproveAndDeposit()
[PASS] testBatchOperationExpired()
[PASS] testEmergencyWithdraw()
[PASS] testExecuteBatchOperations()
[PASS] testExecuteSingleOperation()
[PASS] testGetAllowance()
[PASS] testGetTokenBalance()
[PASS] testInvalidOperation()
[PASS] testPermit2ApproveAndDeposit()
[PASS] testUnauthorizedEmergencyWithdraw()
```

## 🚨 注意事项

1. **EIP-7702 状态**: EIP-7702 目前仍在开发中，前端的委托功能为演示目的
2. **测试网络**: 请在 Sepolia 测试网络上进行测试，不要在主网使用
3. **私钥安全**: 不要在代码中硬编码私钥，使用环境变量
4. **Gas 费用**: 确保账户有足够的 ETH 支付 Gas 费用

## 🔗 相关链接

- [EIP-7702 规范](https://eips.ethereum.org/EIPS/eip-7702)
- [Permit2 文档](https://github.com/Uniswap/permit2)
- [Foundry 文档](https://book.getfoundry.sh/)
- [Sepolia 测试网络](https://sepolia.etherscan.io/)

## 🤝 贡献

欢迎提交 Issue 和 Pull Request 来改进这个项目！

## 📄 许可证

MIT License