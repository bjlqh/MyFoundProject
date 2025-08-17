// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title TokenCustody
 * @dev 中心化托管合约，支持风控检查和合规监控
 */
contract TokenCustody is ReentrancyGuard, AccessControl, Pausable {
    bytes32 public constant COMPLIANCE_ROLE = keccak256("COMPLIANCE_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    
    // 用户余额映射
    mapping(address => mapping(address => uint256)) public userBalances;
    
    // 冻结状态映射
    mapping(address => bool) public frozenAccounts;
    
    // 黑名单映射
    mapping(address => bool) public blacklistedAddresses;
    
    // 交易限额映射
    mapping(address => uint256) public dailyLimits;
    mapping(address => mapping(uint256 => uint256)) public dailySpent;
    
    // 事件定义
    event Deposit(address indexed user, address indexed token, uint256 amount);
    event Withdrawal(address indexed user, address indexed token, uint256 amount);
    event AccountFrozen(address indexed account, string reason);
    event AccountUnfrozen(address indexed account);
    event BlacklistUpdated(address indexed account, bool isBlacklisted);
    event ComplianceCheck(address indexed user, string checkType, bool passed);
    
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(COMPLIANCE_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE, msg.sender);
    }
    
    /**
     * @dev 存款功能，包含合规检查
     */
    function deposit(address token, uint256 amount) 
        external 
        nonReentrant 
        whenNotPaused 
    {
        require(!blacklistedAddresses[msg.sender], "Address is blacklisted");
        require(!frozenAccounts[msg.sender], "Account is frozen");
        require(amount > 0, "Amount must be greater than 0");
        
        // 合规检查
        require(_complianceCheck(msg.sender, amount, "DEPOSIT"), "Compliance check failed");
        
        // 转移代币到合约
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        
        // 更新用户余额
        userBalances[msg.sender][token] += amount;
        
        emit Deposit(msg.sender, token, amount);
        emit ComplianceCheck(msg.sender, "DEPOSIT", true);
    }
    
    /**
     * @dev 提款功能，包含风控检查
     */
    function withdraw(address token, uint256 amount) 
        external 
        nonReentrant 
        whenNotPaused 
    {
        require(!blacklistedAddresses[msg.sender], "Address is blacklisted");
        require(!frozenAccounts[msg.sender], "Account is frozen");
        require(userBalances[msg.sender][token] >= amount, "Insufficient balance");
        
        // 检查日限额
        uint256 today = block.timestamp / 86400;
        require(dailySpent[msg.sender][today] + amount <= dailyLimits[msg.sender], 
                "Daily limit exceeded");
        
        // 合规检查
        require(_complianceCheck(msg.sender, amount, "WITHDRAWAL"), "Compliance check failed");
        
        // 更新余额和日消费
        userBalances[msg.sender][token] -= amount;
        dailySpent[msg.sender][today] += amount;
        
        // 转移代币给用户
        IERC20(token).transfer(msg.sender, amount);
        
        emit Withdrawal(msg.sender, token, amount);
        emit ComplianceCheck(msg.sender, "WITHDRAWAL", true);
    }
    
    /**
     * @dev 冻结账户（合规功能）
     */
    function freezeAccount(address account, string memory reason) 
        external 
        onlyRole(COMPLIANCE_ROLE) 
    {
        frozenAccounts[account] = true;
        emit AccountFrozen(account, reason);
    }
    
    /**
     * @dev 解冻账户
     */
    function unfreezeAccount(address account) 
        external 
        onlyRole(COMPLIANCE_ROLE) 
    {
        frozenAccounts[account] = false;
        emit AccountUnfrozen(account);
    }
    
    /**
     * @dev 更新黑名单
     */
    function updateBlacklist(address account, bool isBlacklisted) 
        external 
        onlyRole(COMPLIANCE_ROLE) 
    {
        blacklistedAddresses[account] = isBlacklisted;
        emit BlacklistUpdated(account, isBlacklisted);
    }
    
    /**
     * @dev 设置日限额
     */
    function setDailyLimit(address user, uint256 limit) 
        external 
        onlyRole(OPERATOR_ROLE) 
    {
        dailyLimits[user] = limit;
    }
    
    /**
     * @dev 紧急暂停
     */
    function emergencyPause() external onlyRole(COMPLIANCE_ROLE) {
        _pause();
    }
    
    /**
     * @dev 恢复操作
     */
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
    
    /**
     * @dev 内部合规检查函数
     */
    function _complianceCheck(address user, uint256 amount, string memory txType) pure
        internal 
        returns (bool) 
    {
        // 这里可以集成外部合规检查逻辑
        // 例如调用预言机或其他合约进行风险评估
        
        // 基础检查：大额交易需要额外验证
        if (amount > 100000 * 10**18) { // 假设是100k代币
            // 大额交易需要离线审批，这里简化处理
            return false;
        }
        
        return true;
    }
    
    /**
     * @dev 获取用户余额
     */
    function getBalance(address user, address token) 
        external 
        view 
        returns (uint256) 
    {
        return userBalances[user][token];
    }
    
    /**
     * @dev 获取今日已消费额度
     */
    function getTodaySpent(address user) external view returns (uint256) {
        uint256 today = block.timestamp / 86400;
        return dailySpent[user][today];
    }
}