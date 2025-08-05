// EIP-7702 TokenBank Demo JavaScript

// 等待 ethers.js 库加载完成
function waitForEthers() {
    return new Promise((resolve) => {
        if (typeof window.ethers !== 'undefined') {
            resolve();
        } else {
            const checkEthers = () => {
                if (typeof window.ethers !== 'undefined') {
                    resolve();
                } else {
                    setTimeout(checkEthers, 100);
                }
            };
            checkEthers();
        }
    });
}

class TokenBankApp {
    constructor() {
        this.provider = null;
        this.signer = null;
        this.userAddress = null;
        this.contracts = {};
        this.transactionHistory = [];
        
        // 合约 ABI (简化版)
        this.abis = {
            token: [
                "function balanceOf(address) view returns (uint256)",
                "function approve(address spender, uint256 amount) returns (bool)",
                "function allowance(address owner, address spender) view returns (uint256)",
                "function transfer(address to, uint256 amount) returns (bool)",
                "function decimals() view returns (uint8)",
                "function symbol() view returns (string)"
            ],
            tokenBank: [
                "function balances(address) view returns (uint256)",
                "function deposit(uint256 amount)",
                "function withdraw(uint256 amount)",
                "function permitDeposit(uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s)",
                "function depositWithPermit2(address owner, uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s)"
            ],
            delegate: [
                "function approveAndDeposit(address token, address bank, uint256 amount)",
                "function permit2ApproveAndDeposit(address token, address bank, address permit2, uint256 amount)",
                "function executeBatch((uint8 opType, address target, uint256 amount, bytes data)[] operations, uint256 deadline)",
                "function executeOperation((uint8 opType, address target, uint256 amount, bytes data) op)",
                "function getTokenBalance(address token) view returns (uint256)",
                "function getAllowance(address token, address spender) view returns (uint256)"
            ]
        };
        
        this.init();
    }
    
    async init() {
        this.setupEventListeners();
        await this.checkWalletConnection();
    }
    
    setupEventListeners() {
        // 钱包连接
        document.getElementById('connect-wallet').addEventListener('click', () => this.connectWallet());
        document.getElementById('switch-network').addEventListener('click', () => this.switchToSepolia());
        
        // 合约加载
        document.getElementById('load-contracts').addEventListener('click', () => this.loadContracts());
        
        // 余额刷新
        document.getElementById('refresh-balances').addEventListener('click', () => this.refreshBalances());
        
        // 操作按钮
        document.getElementById('approve-and-deposit').addEventListener('click', () => this.approveAndDeposit());
        document.getElementById('permit2-approve-deposit').addEventListener('click', () => this.permit2ApproveAndDeposit());
        document.getElementById('execute-batch').addEventListener('click', () => this.executeBatchOperation());
        document.getElementById('delegate-account').addEventListener('click', () => this.delegateAccount());
        
        // 合约加载
        document.getElementById('load-contracts').addEventListener('click', () => this.loadContracts());
        
        // 余额刷新
        document.getElementById('refresh-balances').addEventListener('click', () => this.refreshBalances());
        
        // 操作按钮
        document.getElementById('approve-and-deposit').addEventListener('click', () => this.approveAndDeposit());
        document.getElementById('permit2-approve-deposit').addEventListener('click', () => this.permit2ApproveAndDeposit());
        document.getElementById('execute-batch').addEventListener('click', () => this.executeBatchOperation());
        document.getElementById('delegate-account').addEventListener('click', () => this.delegateAccount());
    }
    
    async checkWalletConnection() {
        if (typeof window.ethereum !== 'undefined') {
            try {
                const accounts = await window.ethereum.request({ method: 'eth_accounts' });
                if (accounts.length > 0) {
                    await this.connectWallet();
                }
            } catch (error) {
                console.error('检查钱包连接失败:', error);
            }
        } else {
            this.showStatus('请安装 MetaMask 钱包', 'error');
        }
    }
    
    async connectWallet() {
        try {
            if (typeof window.ethereum === 'undefined') {
                throw new Error('请安装 MetaMask');
            }
            
            this.showStatus('正在连接钱包...', 'info');
            
            // 请求账户访问
            await window.ethereum.request({ method: 'eth_requestAccounts' });
            
            // 创建 provider 和 signer
            this.provider = new window.ethers.providers.Web3Provider(window.ethereum);
            this.signer = this.provider.getSigner();
            this.userAddress = await this.signer.getAddress();
            
            // 检查网络
            const network = await this.provider.getNetwork();
            if (network.chainId !== 11155111) { // Sepolia chainId
                document.getElementById('switch-network').style.display = 'inline-block';
                this.showStatus('请切换到 Sepolia 测试网络', 'error');
                return;
            }
            
            // 更新 UI
            document.getElementById('wallet-address').textContent = this.userAddress;
            document.getElementById('account-info').style.display = 'block';
            document.getElementById('connect-wallet').textContent = '已连接';
            document.getElementById('connect-wallet').disabled = true;
            
            this.showStatus('钱包连接成功!', 'success');
            
            // 监听账户变化
            window.ethereum.on('accountsChanged', (accounts) => {
                if (accounts.length === 0) {
                    this.disconnectWallet();
                } else {
                    window.location.reload();
                }
            });
            
            // 监听网络变化
            window.ethereum.on('chainChanged', () => {
                window.location.reload();
            });
            
        } catch (error) {
            console.error('连接钱包失败:', error);
            this.showStatus(`连接失败: ${error.message}`, 'error');
        }
    }
    
    async switchToSepolia() {
        try {
            await window.ethereum.request({
                method: 'wallet_switchEthereumChain',
                params: [{ chainId: '0xaa36a7' }], // Sepolia chainId in hex
            });
        } catch (error) {
            if (error.code === 4902) {
                // 网络不存在，添加网络
                try {
                    await window.ethereum.request({
                        method: 'wallet_addEthereumChain',
                        params: [{
                            chainId: '0xaa36a7',
                            chainName: 'Sepolia Test Network',
                            nativeCurrency: {
                                name: 'ETH',
                                symbol: 'ETH',
                                decimals: 18
                            },
                            rpcUrls: ['https://sepolia.infura.io/v3/'],
                            blockExplorerUrls: ['https://sepolia.etherscan.io/']
                        }]
                    });
                } catch (addError) {
                    console.error('添加网络失败:', addError);
                }
            }
        }
    }
    
    disconnectWallet() {
        this.provider = null;
        this.signer = null;
        this.userAddress = null;
        this.contracts = {};
        
        document.getElementById('account-info').style.display = 'none';
        document.getElementById('eip7702-operations').style.display = 'none';
        document.getElementById('transaction-history').style.display = 'none';
        document.getElementById('connect-wallet').textContent = '连接 MetaMask';
        document.getElementById('connect-wallet').disabled = false;
        
        this.showStatus('钱包已断开连接', 'info');
    }
    
    async loadContracts() {
        try {
            if (!this.signer) {
                throw new Error('请先连接钱包');
            }
            
            const tokenAddress = document.getElementById('token-address').value;
            const bankAddress = document.getElementById('bank-address').value;
            const delegateAddress = document.getElementById('delegate-address').value;
            
            if (!tokenAddress || !bankAddress || !delegateAddress) {
                throw new Error('请填写所有合约地址');
            }
            
            this.showStatus('正在加载合约...', 'info');
            
            // 创建合约实例
            this.contracts.token = new window.ethers.Contract(tokenAddress, this.abis.token, this.signer);
            this.contracts.bank = new window.ethers.Contract(bankAddress, this.abis.tokenBank, this.signer);
            this.contracts.delegate = new window.ethers.Contract(delegateAddress, this.abis.delegate, this.signer);
            
            // 测试合约连接
            await this.contracts.token.symbol();
            
            document.getElementById('eip7702-operations').style.display = 'block';
            document.getElementById('transaction-history').style.display = 'block';
            
            this.showStatus('合约加载成功!', 'success');
            await this.refreshBalances();
            
        } catch (error) {
            console.error('加载合约失败:', error);
            this.showStatus(`加载合约失败: ${error.message}`, 'error');
        }
    }
    
    async refreshBalances() {
        try {
            if (!this.contracts.token || !this.contracts.bank) {
                return;
            }
            
            // 获取余额
            const tokenBalance = await this.contracts.token.balanceOf(this.userAddress);
            const bankBalance = await this.contracts.bank.balances(this.userAddress);
            const ethBalance = await this.provider.getBalance(this.userAddress);
            const decimals = await this.contracts.token.decimals();
            const symbol = await this.contracts.token.symbol();
            
            // 更新显示
            document.getElementById('token-balance').textContent = 
                `${window.ethers.utils.formatUnits(tokenBalance, decimals)} ${symbol}`;
            document.getElementById('bank-balance').textContent = 
                `${window.ethers.utils.formatUnits(bankBalance, decimals)} ${symbol}`;
            document.getElementById('eth-balance').textContent = 
                `${window.ethers.utils.formatEther(ethBalance)} ETH`;
                
        } catch (error) {
            console.error('刷新余额失败:', error);
        }
    }
    
    async approveAndDeposit() {
        try {
            const amount = document.getElementById('single-amount').value;
            if (!amount || amount <= 0) {
                throw new Error('请输入有效的金额');
            }
            
            const decimals = await this.contracts.token.decimals();
            const amountWei = window.ethers.utils.parseUnits(amount, decimals);
            
            this.showStatus('正在执行授权并存款...', 'info');
            
            // 使用 Delegate 合约的 approveAndDeposit 方法
            const tx = await this.contracts.delegate.approveAndDeposit(
                this.contracts.token.address,
                this.contracts.bank.address,
                amountWei
            );
            
            this.addToHistory('授权并存款', tx.hash, 'pending');
            
            const receipt = await tx.wait();
            this.updateHistoryStatus(tx.hash, 'success');
            
            this.showStatus('授权并存款成功!', 'success');
            await this.refreshBalances();
            
        } catch (error) {
            console.error('授权并存款失败:', error);
            this.showStatus(`操作失败: ${error.message}`, 'error');
        }
    }
    
    async permit2ApproveAndDeposit() {
        try {
            const amount = document.getElementById('single-amount').value;
            if (!amount || amount <= 0) {
                throw new Error('请输入有效的金额');
            }
            
            const decimals = await this.contracts.token.decimals();
            const amountWei = window.ethers.utils.parseUnits(amount, decimals);
            const permit2Address = document.getElementById('permit2-address').value;
            
            this.showStatus('正在执行 Permit2 授权并存款...', 'info');
            
            // 使用 Delegate 合约的 permit2ApproveAndDeposit 方法
            const tx = await this.contracts.delegate.permit2ApproveAndDeposit(
                this.contracts.token.address,
                this.contracts.bank.address,
                permit2Address,
                amountWei
            );
            
            this.addToHistory('Permit2授权并存款', tx.hash, 'pending');
            
            const receipt = await tx.wait();
            this.updateHistoryStatus(tx.hash, 'success');
            
            this.showStatus('Permit2 授权并存款成功!', 'success');
            await this.refreshBalances();
            
        } catch (error) {
            console.error('Permit2 授权并存款失败:', error);
            this.showStatus(`操作失败: ${error.message}`, 'error');
        }
    }
    
    async executeBatchOperation() {
        try {
            const amount = document.getElementById('batch-amount').value;
            const operationType = document.getElementById('operation-type').value;
            
            if (!amount || amount <= 0) {
                throw new Error('请输入有效的金额');
            }
            
            const decimals = await this.contracts.token.decimals();
            const amountWei = window.ethers.utils.parseUnits(amount, decimals);
            
            this.showStatus('正在执行批量操作...', 'info');
            
            let operations = [];
            
            if (operationType === 'approve-deposit') {
                // 操作1: 授权代币
                operations.push({
                    opType: 0, // APPROVE_TOKEN
                    target: this.contracts.token.address,
                    amount: amountWei,
                    data: window.ethers.utils.defaultAbiCoder.encode(['address'], [this.contracts.bank.address])
                });
                
                // 操作2: 存款
                operations.push({
                    opType: 1, // DEPOSIT_TO_BANK
                    target: this.contracts.bank.address,
                    amount: amountWei,
                    data: '0x'
                });
            } else if (operationType === 'permit2-approve-deposit') {
                const permit2Address = document.getElementById('permit2-address').value;
                
                // 操作1: Permit2授权
                operations.push({
                    opType: 2, // PERMIT2_APPROVE
                    target: this.contracts.token.address,
                    amount: amountWei,
                    data: window.ethers.utils.defaultAbiCoder.encode(['address'], [permit2Address])
                });
                
                // 操作2: 存款
                operations.push({
                    opType: 3, // PERMIT2_DEPOSIT
                    target: this.contracts.bank.address,
                    amount: amountWei,
                    data: '0x'
                });
            }
            
            const batchOp = {
                operations: operations,
                deadline: Math.floor(Date.now() / 1000) + 3600 // 1小时后过期
            };
            
            const tx = await this.contracts.delegate.executeBatch(batchOp);
            
            this.addToHistory('批量操作', tx.hash, 'pending');
            
            const receipt = await tx.wait();
            this.updateHistoryStatus(tx.hash, 'success');
            
            this.showStatus('批量操作成功!', 'success');
            await this.refreshBalances();
            
        } catch (error) {
            console.error('批量操作失败:', error);
            this.showStatus(`批量操作失败: ${error.message}`, 'error');
        }
    }
    
    async delegateAccount() {
        try {
            this.showStatus('EIP-7702 账户委托功能正在开发中...', 'info');
            
            // 注意: EIP-7702 目前仍在开发阶段，这里只是演示概念
            // 实际实现需要等待 EIP-7702 正式发布和客户端支持
            
            const confirmed = confirm(
                'EIP-7702 账户委托是实验性功能，可能会影响您的账户安全。\n' +
                '这个演示只会显示概念，不会实际修改您的账户。\n' +
                '是否继续?'
            );
            
            if (!confirmed) {
                return;
            }
            
            // 模拟 EIP-7702 委托过程
            this.showStatus('正在准备 EIP-7702 委托交易...', 'info');
            
            // 这里应该是 EIP-7702 的实际实现
            // 目前只是演示概念
            setTimeout(() => {
                this.showStatus(
                    'EIP-7702 委托演示完成。实际功能需要等待以太坊客户端支持。', 
                    'info'
                );
            }, 2000);
            
        } catch (error) {
            console.error('账户委托失败:', error);
            this.showStatus(`账户委托失败: ${error.message}`, 'error');
        }
    }
    
    addToHistory(operation, txHash, status) {
        const historyItem = {
            id: Date.now(),
            operation,
            txHash,
            status,
            timestamp: new Date().toLocaleString()
        };
        
        this.transactionHistory.unshift(historyItem);
        this.updateHistoryDisplay();
    }
    
    updateHistoryStatus(txHash, newStatus) {
        const item = this.transactionHistory.find(item => item.txHash === txHash);
        if (item) {
            item.status = newStatus;
            this.updateHistoryDisplay();
        }
    }
    
    updateHistoryDisplay() {
        const historyList = document.getElementById('history-list');
        
        if (this.transactionHistory.length === 0) {
            historyList.innerHTML = '<p>暂无操作历史</p>';
            return;
        }
        
        historyList.innerHTML = this.transactionHistory.map(item => `
            <div class="card">
                <div style="display: flex; justify-content: space-between; align-items: center;">
                    <div>
                        <strong>${item.operation}</strong>
                        <div class="address">${item.txHash}</div>
                        <small>${item.timestamp}</small>
                    </div>
                    <div class="status ${item.status}">
                        ${item.status === 'pending' ? '⏳ 处理中' : 
                          item.status === 'success' ? '✅ 成功' : '❌ 失败'}
                    </div>
                </div>
            </div>
        `).join('');
    }
    
    showStatus(message, type = 'info') {
        const statusElement = document.getElementById('wallet-status');
        statusElement.textContent = message;
        statusElement.className = `status ${type}`;
    }
}

// 初始化应用
// 等待页面和 ethers.js 库加载完成后初始化应用
window.addEventListener('DOMContentLoaded', async () => {
    try {
        await waitForEthers();
        console.log('Ethers.js loaded successfully');
        const app = new TokenBankApp();
    } catch (error) {
        console.error('Failed to initialize app:', error);
        document.getElementById('status').innerHTML = `
            <div class="alert alert-error">
                <strong>错误:</strong> 无法加载 ethers.js 库，请刷新页面重试。
            </div>
        `;
    }
});