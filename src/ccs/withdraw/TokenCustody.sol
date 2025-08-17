// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract TokenCustody is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    event Deposit(address indexed user, address indexed token, uint256 amount);
    event Withdraw(address indexed user, address indexed token, uint256 amount, bytes32 indexed requestId);
    event BatchWithdraw(bytes32 indexed batchId, uint256 count);
    event EmergencyWithdraw(address indexed token, address indexed to, uint256 amount);
    event TokenAdded(address indexed token, bool enabled);
    event TokenStatusChanged(address indexed token, bool enabled);
    event WithdrawLimitSet(address indexed token, uint256 dailyLimit);

    struct WithdrawRequest {
        address user;
        address token;
        uint256 amount;
        uint256 timestamp;
        bool executed;
    }

    struct TokenInfo {
        bool enabled;
        uint256 dailyLimit;
        mapping(uint256 => uint256) dailyWithdrawn; // day => amount
    }

    mapping(address => TokenInfo) public tokenInfo;
    mapping(address => address[]) public userTokens;
    mapping(address => mapping(address => uint256)) public userBalances;
    mapping(bytes32 => WithdrawRequest) public withdrawRequests;
    mapping(address => bool) public operators;
    
    address[] public supportedTokens;
    uint256 public withdrawDelay = 1 hours;
    uint256 public maxBatchSize = 100;

    modifier onlyOperator() {
        require(operators[msg.sender] || msg.sender == owner(), "not operator");
        _;
    }

    modifier validToken(address _token) {
        require(tokenInfo[_token].enabled, "token not supported");
        _;
    }

    constructor() {}

    // 添加支持的代币
    function addToken(address _token, uint256 _dailyLimit) external onlyOwner {
        require(_token != address(0), "invalid token");
        require(!tokenInfo[_token].enabled, "token already added");
        
        tokenInfo[_token].enabled = true;
        tokenInfo[_token].dailyLimit = _dailyLimit;
        supportedTokens.push(_token);
        
        emit TokenAdded(_token, true);
    }

    // 设置代币状态
    function setTokenStatus(address _token, bool _enabled) external onlyOwner {
        require(tokenInfo[_token].enabled != _enabled, "status unchanged");
        
        tokenInfo[_token].enabled = _enabled;
        
        emit TokenStatusChanged(_token, _enabled);
    }

    // 设置提现限额
    function setWithdrawLimit(address _token, uint256 _dailyLimit) external onlyOwner {
        tokenInfo[_token].dailyLimit = _dailyLimit;
        
        emit WithdrawLimitSet(_token, _dailyLimit);
    }

    // 设置操作员
    function setOperator(address _operator, bool _status) external onlyOwner {
        operators[_operator] = _status;
    }

    // 用户存款
    function deposit(address _token, uint256 _amount) 
        external 
        nonReentrant 
        whenNotPaused 
        validToken(_token) 
    {
        require(_amount > 0, "amount must be positive");
        
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        
        if (userBalances[msg.sender][_token] == 0) {
            userTokens[msg.sender].push(_token);
        }
        
        userBalances[msg.sender][_token] += _amount;
        
        emit Deposit(msg.sender, _token, _amount);
    }

    // 提交提现请求
    function submitWithdrawRequest(
        address _user,
        address _token,
        uint256 _amount,
        bytes32 _requestId
    ) external onlyOperator validToken(_token) {
        require(_amount > 0, "amount must be positive");
        require(userBalances[_user][_token] >= _amount, "insufficient balance");
        require(withdrawRequests[_requestId].timestamp == 0, "request exists");
        
        // 检查日限额
        uint256 today = block.timestamp / 1 days;
        require(
            tokenInfo[_token].dailyWithdrawn[today] + _amount <= tokenInfo[_token].dailyLimit,
            "daily limit exceeded"
        );
        
        withdrawRequests[_requestId] = WithdrawRequest({
            user: _user,
            token: _token,
            amount: _amount,
            timestamp: block.timestamp,
            executed: false
        });
        
        // 冻结用户余额
        userBalances[_user][_token] -= _amount;
    }

    // 执行提现
    function executeWithdraw(bytes32 _requestId) 
        external 
        onlyOperator 
        nonReentrant 
        whenNotPaused 
    {
        WithdrawRequest storage request = withdrawRequests[_requestId];
        require(request.timestamp > 0, "request not found");
        require(!request.executed, "already executed");
        require(
            block.timestamp >= request.timestamp + withdrawDelay,
            "withdraw delay not met"
        );
        
        request.executed = true;
        
        // 更新日限额使用量
        uint256 today = block.timestamp / 1 days;
        tokenInfo[request.token].dailyWithdrawn[today] += request.amount;
        
        IERC20(request.token).safeTransfer(request.user, request.amount);
        
        emit Withdraw(request.user, request.token, request.amount, _requestId);
    }

    // 批量执行提现
    function batchExecuteWithdraw(bytes32[] calldata _requestIds) 
        external 
        onlyOperator 
        nonReentrant 
        whenNotPaused 
    {
        require(_requestIds.length <= maxBatchSize, "batch too large");
        
        bytes32 batchId = keccak256(abi.encodePacked(block.timestamp, _requestIds));
        
        for (uint256 i = 0; i < _requestIds.length; i++) {
            bytes32 requestId = _requestIds[i];
            WithdrawRequest storage request = withdrawRequests[requestId];
            
            if (request.timestamp > 0 && 
                !request.executed && 
                block.timestamp >= request.timestamp + withdrawDelay) {
                
                request.executed = true;
                
                // 更新日限额使用量
                uint256 today = block.timestamp / 1 days;
                if (tokenInfo[request.token].dailyWithdrawn[today] + request.amount <= 
                    tokenInfo[request.token].dailyLimit) {
                    
                    tokenInfo[request.token].dailyWithdrawn[today] += request.amount;
                    IERC20(request.token).safeTransfer(request.user, request.amount);
                    
                    emit Withdraw(request.user, request.token, request.amount, requestId);
                }
            }
        }
        
        emit BatchWithdraw(batchId, _requestIds.length);
    }

    // 紧急提现（仅所有者）
    function emergencyWithdraw(address _token, address _to, uint256 _amount) 
        external 
        onlyOwner 
        nonReentrant 
    {
        require(_to != address(0), "invalid recipient");
        require(_amount > 0, "amount must be positive");
        
        IERC20(_token).safeTransfer(_to, _amount);
        
        emit EmergencyWithdraw(_token, _to, _amount);
    }

    // 暂停/恢复合约
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // 查询用户余额
    function getUserBalance(address _user, address _token) 
        external 
        view 
        returns (uint256) 
    {
        return userBalances[_user][_token];
    }

    // 查询用户所有代币
    function getUserTokens(address _user) 
        external 
        view 
        returns (address[] memory) 
    {
        return userTokens[_user];
    }

    // 查询支持的代币列表
    function getSupportedTokens() external view returns (address[] memory) {
        return supportedTokens;
    }

    // 查询日限额使用情况
    function getDailyWithdrawn(address _token, uint256 _day) 
        external 
        view 
        returns (uint256) 
    {
        return tokenInfo[_token].dailyWithdrawn[_day];
    }

    // 查询今日剩余限额
    function getRemainingDailyLimit(address _token) 
        external 
        view 
        returns (uint256) 
    {
        uint256 today = block.timestamp / 1 days;
        uint256 used = tokenInfo[_token].dailyWithdrawn[today];
        uint256 limit = tokenInfo[_token].dailyLimit;
        
        return limit > used ? limit - used : 0;
    }
}