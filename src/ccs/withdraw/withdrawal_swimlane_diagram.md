# 中心化托管系统提现流程泳道图

## 系统角色泳道图

```mermaid
flowchart TD
    %% 定义泳道
    subgraph "普通用户泳道"
        A1["登录系统"]
        A2["填写提现申请"]
        A3["提交提现请求"]
        A4["查看审批状态"]
        A5["接收提现结果通知"]
    end
    
    subgraph "财务审批员泳道"
        B1["接收审批任务"]
        B2["审核提现金额"]
        B3["验证用户身份"]
        B4["财务审批通过/拒绝"]
    end
    
    subgraph "风控审批员泳道"
        C1["接收风控任务"]
        C2["地址风险评估"]
        C3["行为模式分析"]
        C4["风控审批通过/拒绝"]
    end
    
    subgraph "系统管理员泳道"
        D1["监控系统状态"]
        D2["处理异常情况"]
        D3["执行紧急操作"]
        D4["系统配置管理"]
    end
    
    subgraph "系统服务泳道"
        E1["用户认证服务"]
        E2["提现申请服务"]
        E3["风控检测服务"]
        E4["审批流程服务"]
        E5["钱包管理服务"]
        E6["交易执行服务"]
        E7["通知服务"]
    end
    
    subgraph "区块链泳道"
        F1["TokenCustody合约"]
        F2["MultiSigWallet合约"]
        F3["ERC20代币合约"]
    end
    
    %% 用户流程
    A1 --> E1
    A2 --> E2
    A3 --> E3
    A4 --> E4
    
    %% 财务审批流程
    E4 --> B1
    B1 --> B2
    B2 --> B3
    B3 --> B4
    B4 --> E4
    
    %% 风控审批流程
    E3 --> C1
    C1 --> C2
    C2 --> C3
    C3 --> C4
    C4 --> E4
    
    %% 系统管理流程
    D1 --> E5
    D2 --> E6
    D3 --> F1
    D4 --> E4
    
    %% 服务间调用
    E4 --> E5
    E5 --> E6
    E6 --> F1
    E6 --> F2
    
    %% 合约调用
    F1 --> F3
    F2 --> F3
    
    %% 通知流程
    E6 --> E7
    E7 --> A5
```

## 详细提现流程泳道图

```mermaid
sequenceDiagram
    participant User as 👤 普通用户
    participant FinanceApprover as 💰 财务审批员
    participant RiskApprover as 🛡️ 风控审批员
    participant SysAdmin as ⚙️ 系统管理员
    participant UserSvc as 🔐 用户服务
    participant WithdrawalSvc as 📤 提现服务
    participant RiskSvc as 🚨 风控服务
    participant ApprovalSvc as ✅ 审批服务
    participant WalletSvc as 💳 钱包服务
    participant BlockchainSvc as ⛓️ 区块链服务
    participant TokenCustody as 📋 TokenCustody合约
    participant MultiSig as 🔐 MultiSig合约
    participant ERC20 as 🪙 ERC20合约
    
    %% 用户发起提现
    User->>UserSvc: 1. 登录认证
    UserSvc-->>User: 认证成功
    
    User->>WithdrawalSvc: 2. 提交提现申请
    Note over User,WithdrawalSvc: POST /api/withdrawal/submit<br/>{token, amount, toAddress}
    
    WithdrawalSvc->>RiskSvc: 3. 触发风控检测
    Note over WithdrawalSvc,RiskSvc: assessWithdrawalRisk()<br/>检查地址风险、行为模式
    
    %% 风控审批员介入
    RiskSvc->>RiskApprover: 4. 发送风控审批任务
    Note over RiskSvc,RiskApprover: 高风险交易需人工审核
    
    RiskApprover->>RiskSvc: 5. 风控审批决策
    Note over RiskApprover,RiskSvc: POST /api/risk/approve<br/>{taskId, decision, reason}
    
    RiskSvc->>ApprovalSvc: 6. 创建审批任务
    Note over RiskSvc,ApprovalSvc: createApprovalTask()<br/>风控通过后进入审批流程
    
    %% 财务审批员介入
    ApprovalSvc->>FinanceApprover: 7. 发送财务审批任务
    Note over ApprovalSvc,FinanceApprover: 邮件/短信通知待审批
    
    FinanceApprover->>ApprovalSvc: 8. 财务审批决策
    Note over FinanceApprover,ApprovalSvc: POST /api/approval/process<br/>{taskId, decision, comments}
    
    %% 系统管理员监控
    SysAdmin->>WalletSvc: 9. 监控钱包状态
    Note over SysAdmin,WalletSvc: GET /api/wallet/status<br/>检查热钱包余额
    
    WalletSvc-->>SysAdmin: 钱包状态报告
    
    %% 执行提现
    ApprovalSvc->>WalletSvc: 10. 执行提现请求
    Note over ApprovalSvc,WalletSvc: executeWithdrawal()<br/>审批通过后执行
    
    WalletSvc->>BlockchainSvc: 11. 调用区块链服务
    
    alt 热钱包提现 (金额 < 10,000 USDT)
        BlockchainSvc->>TokenCustody: 12a. requestWithdrawal()
        Note over BlockchainSvc,TokenCustody: requestWithdrawal(token, amount, to)
        TokenCustody->>ERC20: transfer(to, amount)
        ERC20-->>TokenCustody: 转账结果
        TokenCustody-->>BlockchainSvc: 提现完成
    else 冷钱包提现 (金额 >= 10,000 USDT)
        BlockchainSvc->>MultiSig: 12b. submitTransaction()
        Note over BlockchainSvc,MultiSig: submitTransaction(to, amount, data)
        MultiSig-->>BlockchainSvc: 交易ID
        
        %% 系统管理员多签确认
        SysAdmin->>BlockchainSvc: 13. 多签确认
        Note over SysAdmin,BlockchainSvc: POST /api/multisig/confirm<br/>{txId, signature}
        
        BlockchainSvc->>MultiSig: confirmTransaction(txId)
        
        Note over MultiSig: 达到确认阈值后自动执行
        
        MultiSig->>ERC20: executeTransaction()
        ERC20-->>MultiSig: 执行结果
        MultiSig-->>BlockchainSvc: 交易完成
    end
    
    BlockchainSvc-->>WalletSvc: 12. 返回交易哈希
    WalletSvc-->>ApprovalSvc: 执行结果
    ApprovalSvc-->>WithdrawalSvc: 状态更新
    WithdrawalSvc-->>User: 13. 提现完成通知
    
    %% 异常处理
    alt 系统异常情况
        SysAdmin->>TokenCustody: 14. 紧急暂停
        Note over SysAdmin,TokenCustody: emergencyPause()<br/>暂停所有提现操作
        
        SysAdmin->>TokenCustody: 15. 紧急提现
        Note over SysAdmin,TokenCustody: emergencyWithdraw()<br/>管理员紧急提现
    end
```

## 角色权限矩阵

| 角色 | 权限范围 | 主要操作 | 调用接口 |
|------|----------|----------|----------|
| 👤 **普通用户** | 个人账户 | 提现申请、状态查询 | `/api/withdrawal/submit`<br/>`/api/withdrawal/status` |
| 💰 **财务审批员** | 财务审批 | 审批提现请求、查看财务报表 | `/api/approval/process`<br/>`/api/reports/financial` |
| 🛡️ **风控审批员** | 风险控制 | 风险评估、黑名单管理 | `/api/risk/assess`<br/>`/api/risk/blacklist` |
| ⚙️ **系统管理员** | 系统管理 | 系统配置、紧急操作、多签确认 | `/api/system/config`<br/>`/api/emergency/*`<br/>`/api/multisig/confirm` |

## 关键决策点

### 1. 风控决策点
- **触发条件**: 地址风险评分 > 80 或 单日提现超限
- **决策者**: 风控审批员
- **处理时间**: 2小时内

### 2. 财务审批决策点
- **触发条件**: 金额 > 1,000 USDT
- **决策者**: 财务审批员
- **处理时间**: 4小时内

### 3. 钱包选择决策点
- **热钱包**: 金额 < 10,000 USDT，自动执行
- **冷钱包**: 金额 >= 10,000 USDT，需要多签确认

### 4. 紧急处理决策点
- **触发条件**: 系统异常、安全威胁
- **决策者**: 系统管理员
- **处理方式**: 立即暂停、紧急提现

## 监控指标

- **用户操作**: 提现申请数量、成功率
- **审批效率**: 平均审批时间、审批通过率
- **风控效果**: 风险交易拦截率、误报率
- **系统性能**: 交易处理速度、系统可用性
- **资金安全**: 钱包余额、异常交易监控