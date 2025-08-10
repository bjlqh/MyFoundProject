# TokenBank Permit2 实现

## 概述

在原有的 TokenBank 合约基础上，我们添加了 `depositWithPermit2()` 方法，使用 Permit2 进行离线签名授权转账来进行存款。

## 实现的功能

### 1. SimplePermit2 合约

创建了一个简化版的 Permit2 实现 (`src/bank/SimplePermit2.sol`)，包含以下功能：

- **EIP712 签名验证**：支持离线签名授权
- **授权管理**：管理用户的代币授权额度
- **Nonce 管理**：防止重放攻击
- **代币转移**：使用授权进行代币转移

### 2. TokenBank 合约更新

在 `src/bank/TokenBank.sol` 中添加了以下方法：

#### `depositWithPermit2()`
```solidity
function depositWithPermit2(
    address owner,
    uint256 amount,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
) public
```

**功能**：
- 使用 Permit2 进行离线签名授权存款
- 验证签名并设置授权
- 使用 Permit2 转移代币到银行合约
- 记录用户的存款

#### `depositWithPermit2Batch()`
```solidity
function depositWithPermit2Batch(
    address owner,
    uint256 amount,
    uint256 deadline,
    bytes calldata signature
) public
```

**功能**：
- 支持批量签名授权（简化版本）
- 使用 bytes 格式的签名

#### 辅助函数

- `getPermit2Nonce(address owner)`：获取用户的 nonce
- `checkPermit2Approval(address owner, uint256 amount)`：检查用户是否已授权 Permit2

## 与原有 Permit 的区别

| 特性 | 原有 Permit | Permit2 |
|------|-------------|---------|
| 标准 | EIP-2612 | Uniswap Permit2 |
| 批量支持 | 否 | 是 |
| Gas 效率 | 较低 | 更高 |
| 用户体验 | 一般 | 更好 |
| 实现复杂度 | 简单 | 中等 |

## 使用方法

### 1. 部署合约

```bash
# 设置环境变量
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# 部署合约
forge script script/DeployEIP712Script.s.sol --rpc-url http://localhost:8545 --broadcast
```

### 2. 前端集成

在前端应用中，用户需要：

1. **授权 Permit2 合约**：
```javascript
await token.approve(permit2Address, amount);
```

2. **生成签名**：
```javascript
const permitSingle = {
    details: {
        token: tokenAddress,
        amount: amount,
        expiration: deadline,
        nonce: await tokenBank.getPermit2Nonce(userAddress)
    },
    spender: tokenBankAddress,
    sigDeadline: deadline
};

const signature = await wallet.signTypedData(domain, types, permitSingle);
```

3. **调用存款函数**：
```javascript
await tokenBank.depositWithPermit2(
    userAddress,
    amount,
    deadline,
    signature.v,
    signature.r,
    signature.s
);
```

## 安全考虑

1. **Nonce 验证**：防止重放攻击
2. **签名验证**：确保只有授权用户可以设置授权
3. **过期时间**：签名有过期时间限制
4. **金额限制**：授权金额有限制

## 测试

运行测试：
```bash
forge test --match-contract SimplePermit2Test -vv
```

## 文件结构

```
src/bank/
├── TokenBank.sol          # 更新的银行合约
├── SimplePermit2.sol      # 简化版 Permit2 实现
└── ...

test/
├── SimplePermit2Test.t.sol # Permit2 测试
└── ...

script/
├── DeployEIP712Script.s.sol # 更新的部署脚本
└── ...
```

## 注意事项

1. **版本兼容性**：所有合约使用 Solidity 0.8.17
2. **依赖管理**：需要 OpenZeppelin 合约库
3. **Gas 优化**：Permit2 相比传统 permit 更节省 gas
4. **用户体验**：支持离线签名，无需用户手动授权

## 下一步

1. 完善签名生成的前端工具
2. 添加更多测试用例
3. 优化 gas 使用
4. 添加批量操作支持 