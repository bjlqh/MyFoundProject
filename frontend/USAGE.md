# EIP-7702 TokenBank Demo 使用指南

## 🚀 快速开始

### 1. 访问应用
打开浏览器访问: http://localhost:8000

### 2. 连接钱包
1. 点击 "连接 MetaMask" 按钮
2. 在 MetaMask 中确认连接
3. 如果不在 Sepolia 网络，点击 "切换到 Sepolia" 按钮

### 3. 配置合约地址

由于合约尚未部署到 Sepolia（需要测试 ETH），您需要先部署合约：

```bash
# 获取 Sepolia 测试 ETH
# 访问: https://sepoliafaucet.com/

# 设置环境变量
export PRIVATE_KEY="your_private_key_here"

# 部署合约
forge script script/DeployEIP7702DelegateScript.s.sol \
  --rpc-url sepolia \
  --broadcast
```

然后在前端页面填入部署后的合约地址：
- **Token 合约地址**: 部署的 MyToken 合约地址
- **TokenBank 合约地址**: 部署的 TokenBank 合约地址  
- **EIP7702Delegate 合约地址**: 部署的 EIP7702Delegate 合约地址
- **Permit2 合约地址**: `0x000000000022D473030F116dDEE9F6B43aC78BA3` (已预填)

### 4. 加载合约
点击 "加载合约" 按钮，系统会验证合约地址并建立连接。

## 🎯 功能演示

### 单步操作

#### 授权并存款
1. 在 "单步操作" 区域输入存款金额
2. 点击 "授权并存款" 按钮
3. 在 MetaMask 中确认交易
4. 等待交易确认，余额会自动更新

#### Permit2 授权并存款
1. 输入存款金额
2. 点击 "Permit2 授权并存款" 按钮
3. 确认交易并等待完成

### 批量操作

1. 在 "批量操作" 区域输入金额
2. 选择操作类型：
   - **授权 + 存款**: 传统的两步操作合并为一个交易
   - **Permit2授权 + 存款**: 使用 Permit2 标准的批量操作
3. 点击 "执行批量操作"
4. 确认交易

### EIP-7702 账户委托 (演示)

**注意**: 这是概念演示，实际的 EIP-7702 需要以太坊客户端支持。

1. 点击 "委托账户 (实验性)" 按钮
2. 查看控制台输出了解委托过程

## 🔍 技术特性

### EIP-7702 优势
- **Gas 优化**: 批量操作减少交易数量
- **用户体验**: 一键完成复杂操作
- **账户抽象**: EOA 账户获得智能合约功能

### 安全特性
- **权限控制**: 严格的操作验证
- **时间限制**: 批量操作有过期时间
- **紧急恢复**: 支持资产紧急提取

## 📊 监控和调试

### 余额监控
- 实时显示 ETH、Token 和银行存款余额
- 点击 "刷新余额" 手动更新

### 交易历史
- 查看所有操作的交易哈希和状态
- 点击交易哈希在 Etherscan 上查看详情

### 错误处理
- 详细的错误信息显示
- 控制台日志用于调试

## 🚨 注意事项

1. **测试网络**: 仅在 Sepolia 测试网络使用
2. **测试代币**: 需要先获取测试代币
3. **Gas 费用**: 确保钱包有足够的 ETH 支付 Gas
4. **实验性功能**: EIP-7702 委托为演示功能

## 🔗 相关资源

- [EIP-7702 规范](https://eips.ethereum.org/EIPS/eip-7702)
- [Permit2 文档](https://github.com/Uniswap/permit2)
- [Sepolia 水龙头](https://sepoliafaucet.com/)
- [Sepolia 浏览器](https://sepolia.etherscan.io/)

## 🐛 故障排除

### 常见问题

1. **"ethers is not defined" 错误**
   - 刷新页面重新加载 ethers.js 库

2. **交易失败**
   - 检查 Gas 费用是否足够
   - 确认网络连接正常
   - 查看控制台错误信息

3. **合约加载失败**
   - 验证合约地址格式正确
   - 确认合约已部署到 Sepolia
   - 检查网络连接

4. **余额不更新**
   - 等待交易确认
   - 手动点击 "刷新余额"
   - 检查交易是否成功

### 获取帮助

如果遇到问题，请：
1. 查看浏览器控制台错误信息
2. 检查 MetaMask 交易历史
3. 在 Sepolia Etherscan 上查看交易状态