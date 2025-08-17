# 中心化托管系统 - 风控合规服务泳道图

```mermaid
flowchart TD
    subgraph "用户 (User)"
        U1["提交KYC信息"]
        U2["发起存款交易"]
        U3["发起提款交易"]
        U4["查询账户状态"]
        U5["接收冻结通知"]
    end
    
    subgraph "前端应用 (Frontend)"
        F1["KYC表单提交"]
        F2["交易请求"]
        F3["状态查询"]
        F4["显示告警信息"]
    end
    
    subgraph "后端API服务 (Backend API)"
        B1["KYC信息验证"]
        B2["交易预检查"]
        B3["风险评分计算"]
        B4["黑名单检查"]
        B5["生成STR报告"]
        B6["更新用户状态"]
    end
    
    subgraph "风控引擎 (Risk Engine)"
        R1["实时交易监控"]
        R2["异常模式识别"]
        R3["风险评分更新"]
        R4["触发告警规则"]
    end
    
    subgraph "合规官 (Compliance Officer)"
        C1["审核KYC材料"]
        C2["处理可疑交易"]
        C3["更新黑名单"]
        C4["冻结可疑账户"]
        C5["生成监管报告"]
    end
    
    subgraph "智能合约 (Smart Contract)"
        S1["执行存款操作"]
        S2["执行提款操作"]
        S3["冻结账户"]
        S4["更新黑名单"]
        S5["发出事件日志"]
    end
    
    subgraph "区块链监听服务 (Event Listener)"
        E1["监听合约事件"]
        E2["解析事件数据"]
        E3["发送到消息队列"]
    end
    
    subgraph "数据库 (Database)"
        D1["用户KYC记录"]
        D2["交易历史"]
        D3["黑名单数据"]
        D4["风险评分"]
        D5["合规报告"]
    end
    
    subgraph "外部服务 (External Services)"
        X1["制裁名单API"]
        X2["身份验证服务"]
        X3["监管报送接口"]
    end
    
    %% 用户KYC流程
    U1 --> F1
    F1 --> B1
    B1 --> X2
    B1 --> D1
    B1 --> C1
    C1 --> B6
    B6 --> D1
    
    %% 存款流程
    U2 --> F2
    F2 --> B2
    B2 --> B4
    B4 --> D3
    B2 --> R1
    R1 --> R2
    R2 --> R4
    R4 --> C2
    B2 --> S1
    S1 --> S5
    S5 --> E1
    E1 --> E2
    E2 --> E3
    E3 --> D2
    
    %% 提款流程
    U3 --> F2
    F2 --> B2
    B2 --> B3
    B3 --> R3
    R3 --> D4
    B2 --> S2
    S2 --> S5
    
    %% 风控告警流程
    R4 --> B5
    B5 --> D5
    C2 --> C4
    C4 --> S3
    S3 --> S5
    S5 --> U5
    
    %% 黑名单管理流程
    C3 --> S4
    S4 --> S5
    X1 --> B4
    
    %% 查询流程
    U4 --> F3
    F3 --> B6
    B6 --> D1
    B6 --> D4
    
    %% 监管报告流程
    C5 --> X3
    D5 --> C5
    
    %% 样式定义
    classDef userClass fill:#e1f5fe
    classDef frontendClass fill:#f3e5f5
    classDef backendClass fill:#e8f5e8
    classDef riskClass fill:#fff3e0
    classDef complianceClass fill:#fce4ec
    classDef contractClass fill:#e0f2f1
    classDef listenerClass fill:#f1f8e9
    classDef dbClass fill:#e3f2fd
    classDef externalClass fill:#fafafa
    
    class U1,U2,U3,U4,U5 userClass
    class F1,F2,F3,F4 frontendClass
    class B1,B2,B3,B4,B5,B6 backendClass
    class R1,R2,R3,R4 riskClass
    class C1,C2,C3,C4,C5 complianceClass
    class S1,S2,S3,S4,S5 contractClass
    class E1,E2,E3 listenerClass
    class D1,D2,D3,D4,D5 dbClass
    class X1,X2,X3 externalClass
```

## 详细业务流程说明

### 1. KYC身份验证流程
```mermaid
sequenceDiagram
    participant User as 用户
    participant Frontend as 前端
    participant Backend as 后端API
    participant External as 外部验证
    participant Compliance as 合规官
    participant DB as 数据库
    
    User->>Frontend: 上传身份证件
    Frontend->>Backend: 提交KYC信息
    Backend->>External: 调用身份验证API
    External-->>Backend: 返回验证结果
    Backend->>DB: 保存KYC记录
    Backend->>Compliance: 发送人工审核请求
    Compliance->>Backend: 审核通过/拒绝
    Backend->>DB: 更新用户状态
    Backend-->>Frontend: 返回审核结果
    Frontend-->>User: 显示KYC状态
```

### 2. 交易监控与风控流程
```mermaid
sequenceDiagram
    participant User as 用户
    participant Frontend as 前端
    participant Backend as 后端API
    participant Risk as 风控引擎
    participant Contract as 智能合约
    participant Listener as 事件监听
    participant Compliance as 合规官
    
    User->>Frontend: 发起提款请求
    Frontend->>Backend: 提交交易请求
    Backend->>Risk: 实时风险检查
    Risk-->>Backend: 返回风险评分
    
    alt 风险评分正常
        Backend->>Contract: 调用提款函数
        Contract->>Contract: 执行合规检查
        Contract-->>Backend: 交易成功
        Contract->>Listener: 发出Withdrawal事件
        Listener->>Backend: 更新交易记录
    else 风险评分异常
        Backend->>Risk: 触发告警规则
        Risk->>Compliance: 发送可疑交易告警
        Compliance->>Contract: 冻结账户
        Contract->>Listener: 发出AccountFrozen事件
        Listener->>Backend: 更新账户状态
        Backend-->>Frontend: 返回交易被拒绝
    end
```

### 3. 黑名单管理流程
```mermaid
sequenceDiagram
    participant External as 外部制裁名单
    participant Backend as 后端服务
    participant Compliance as 合规官
    participant Contract as 智能合约
    participant Listener as 事件监听
    participant DB as 数据库
    participant Cache as Redis缓存
    
    External->>Backend: 定期同步制裁名单
    Backend->>DB: 更新黑名单表
    Backend->>Cache: 更新缓存
    
    Compliance->>Contract: 手动添加黑名单地址
    Contract->>Contract: 更新blacklistedAddresses
    Contract->>Listener: 发出BlacklistUpdated事件
    Listener->>Backend: 接收事件数据
    Backend->>DB: 同步黑名单状态
    Backend->>Cache: 更新缓存
```

### 4. 合规报告生成流程
```mermaid
sequenceDiagram
    participant Compliance as 合规官
    participant Backend as 后端服务
    participant DB as 数据库
    participant External as 监管机构
    
    Compliance->>Backend: 请求生成STR报告
    Backend->>DB: 查询可疑交易数据
    DB-->>Backend: 返回交易记录
    Backend->>Backend: 生成报告文件
    Backend-->>Compliance: 返回报告下载链接
    Compliance->>External: 提交监管报告
    External-->>Compliance: 确认接收
    Compliance->>Backend: 更新报送状态
    Backend->>DB: 记录报送历史
```

## 关键角色职责

### 👤 用户 (User)
- 提交KYC身份验证材料
- 发起存款/提款交易
- 查询账户状态和交易历史
- 接收系统通知和告警

### 🖥️ 前端应用 (Frontend)
- 提供用户交互界面
- 表单验证和数据提交
- 显示账户状态和告警信息
- 实时更新交易状态

### ⚙️ 后端API服务 (Backend API)
- 处理业务逻辑
- 数据验证和存储
- 调用外部服务
- 生成合规报告

### 🛡️ 风控引擎 (Risk Engine)
- 实时交易监控
- 异常模式识别
- 风险评分计算
- 告警规则触发

### 👨‍💼 合规官 (Compliance Officer)
- KYC材料人工审核
- 可疑交易调查
- 黑名单维护
- 监管报告生成

### 📜 智能合约 (Smart Contract)
- 资金托管和转移
- 合规规则执行
- 账户状态管理
- 事件日志记录

### 👂 事件监听服务 (Event Listener)
- 监听区块链事件
- 数据解析和转换
- 消息队列分发
- 数据同步

这个泳道图完整展示了中心化托管系统中各个角色的交互流程，确保了合规性、安全性和可追溯性。