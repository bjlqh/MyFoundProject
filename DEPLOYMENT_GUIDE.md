# 可升级合约部署指南

## 概述
本项目使用 UUPS (Universal Upgradeable Proxy Standard) 代理模式实现可升级的 NFT 市场合约。

## 本地部署 (已完成)

### 部署的合约地址

#### 代理合约地址 (用户交互地址)
- **NFT 市场代理合约**: `0x4ed7c70F96B99c776995fB64377f0d4aB3B0e1C1`
- **NFT 代理合约**: `0xc6e7DF5E7b4f2A278906862b61205850344D4e7d`

#### 实现合约地址 (逻辑合约)
- **NFTMarketV1 实现合约**: `0x59b670e9fA9D0A427751Af201D676719a970857b`
- **NFTMarketV2 实现合约**: `0x322813Fd9A801c5507c9de605d63CEA4f2CE6c44`
- **MyERC721Upgradeable 实现合约**: `0x3Aa5ebB10DC797CAC828524e59A333d0A371443c`

#### 其他合约
- **MyToken (ERC20)**: `0x68B1D87F95878fE05B998F19b66F4baba5De1aed`
- **白名单签名者**: `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266`

### 部署命令
```bash
forge script script/DeployUpgradeableNFTMarket.s.sol --rpc-url local --broadcast --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

## 测试网部署指南

### 1. 准备工作

#### 获取测试网 ETH
- **Sepolia 测试网**: 访问 [Sepolia Faucet](https://sepoliafaucet.com/) 获取测试 ETH
- **Goerli 测试网**: 访问 [Goerli Faucet](https://goerlifaucet.com/) 获取测试 ETH

#### 配置环境变量
```bash
# 在 .env 文件中设置
PRIVATE_KEY=your_private_key_here
ETHERSCAN_API_KEY=your_etherscan_api_key_here
```

### 2. 部署到 Sepolia 测试网

```bash
# 部署合约
forge script script/DeployUpgradeableNFTMarket.s.sol \
  --rpc-url sepolia \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --private-key $PRIVATE_KEY
```

### 3. 手动验证合约 (如果自动验证失败)

#### 验证实现合约
```bash
# 验证 NFTMarketV1 实现合约
forge verify-contract \
  --chain-id 11155111 \
  --num-of-optimizations 200 \
  --watch \
  --constructor-args $(cast abi-encode "constructor()" ) \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --compiler-version v0.8.17+commit.8df45f5f \
  <NFTMarketV1_IMPLEMENTATION_ADDRESS> \
  src/NFTMarketV1.sol:NFTMarketV1

# 验证 NFTMarketV2 实现合约
forge verify-contract \
  --chain-id 11155111 \
  --num-of-optimizations 200 \
  --watch \
  --constructor-args $(cast abi-encode "constructor()" ) \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --compiler-version v0.8.17+commit.8df45f5f \
  <NFTMarketV2_IMPLEMENTATION_ADDRESS> \
  src/NFTMarketV2.sol:NFTMarketV2

# 验证 MyERC721Upgradeable 实现合约
forge verify-contract \
  --chain-id 11155111 \
  --num-of-optimizations 200 \
  --watch \
  --constructor-args $(cast abi-encode "constructor()" ) \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --compiler-version v0.8.17+commit.8df45f5f \
  <MyERC721Upgradeable_IMPLEMENTATION_ADDRESS> \
  src/MyERC721Upgradeable.sol:MyERC721Upgradeable
```

#### 验证代理合约
```bash
# 验证 NFT 市场代理合约
forge verify-contract \
  --chain-id 11155111 \
  --num-of-optimizations 200 \
  --watch \
  --constructor-args $(cast abi-encode "constructor(address,bytes)" <IMPLEMENTATION_ADDRESS> <INIT_DATA>) \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --compiler-version v0.8.17+commit.8df45f5f \
  <PROXY_ADDRESS> \
  lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy
```

### 4. 在区块链浏览器上开源

#### Etherscan 验证步骤
1. 访问 [Etherscan](https://sepolia.etherscan.io/) (Sepolia 测试网)
2. 搜索合约地址
3. 点击 "Contract" 标签
4. 点击 "Verify and Publish"
5. 选择 "Solidity (Single file)" 或 "Solidity (Standard JSON Input)"
6. 填写合约信息：
   - Compiler Type: Solidity (Single file)
   - Compiler Version: v0.8.17+commit.8df45f5f
   - Open Source License Type: MIT
7. 粘贴合约源码或上传 JSON 文件
8. 点击 "Verify and Publish"

### 5. 升级合约示例

```bash
# 创建升级脚本
forge script script/UpgradeNFTMarket.s.sol \
  --rpc-url sepolia \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --private-key $PRIVATE_KEY
```

## 重要说明

### UUPS 代理模式特点
1. **代理合约地址不变**: 用户始终与代理合约交互
2. **实现合约可升级**: 通过部署新的实现合约并调用升级函数
3. **状态保持**: 升级后所有状态数据保持不变
4. **权限控制**: 只有授权用户可以执行升级操作

### 安全注意事项
1. **存储布局兼容性**: 升级时必须保持存储布局兼容
2. **初始化函数**: 新版本如需初始化，使用 `reinitializer` 修饰符
3. **权限管理**: 确保升级权限只授予可信地址
4. **测试充分**: 在测试网充分测试后再部署到主网

### 合约交互
```bash
# 与代理合约交互 (使用代理地址)
cast call <PROXY_ADDRESS> "owner()" --rpc-url sepolia

# 调用 V2 新功能
cast send <PROXY_ADDRESS> "listWithSignature(uint256,uint256,uint256,bytes)" \
  1 1000000000000000000 1234567890 0x... \
  --private-key $PRIVATE_KEY \
  --rpc-url sepolia
```

## 故障排除

### 常见问题
1. **余额不足**: 确保账户有足够的测试网 ETH
2. **Gas 估算失败**: 检查合约代码和网络状态
3. **验证失败**: 确保编译器版本和优化设置正确
4. **升级失败**: 检查权限和存储布局兼容性

### 有用的命令
```bash
# 检查合约代码
cast code <CONTRACT_ADDRESS> --rpc-url sepolia

# 检查账户余额
cast balance <ADDRESS> --rpc-url sepolia

# 获取交易详情
cast tx <TX_HASH> --rpc-url sepolia
```