// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title MultiSigWallet
 * @dev 多签钱包合约，用于托管系统的资金管理
 */
contract MultiSigWallet is ReentrancyGuard {
    
    // 交易结构体
    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 confirmations;
        mapping(address => bool) isConfirmed;
    }
    
    // 状态变量
    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public required;
    uint256 public transactionCount;
    mapping(uint256 => Transaction) public transactions;
    
    // 事件
    event Deposit(address indexed sender, uint256 value);
    event SubmitTransaction(address indexed owner, uint256 indexed txIndex);
    event ConfirmTransaction(address indexed owner, uint256 indexed txIndex);
    event RevokeConfirmation(address indexed owner, uint256 indexed txIndex);
    event ExecuteTransaction(address indexed owner, uint256 indexed txIndex);
    event OwnerAddition(address indexed owner);
    event OwnerRemoval(address indexed owner);
    event RequirementChange(uint256 required);
    
    // 修饰符
    modifier onlyOwner() {
        require(isOwner[msg.sender], "Not an owner");
        _;
    }
    
    modifier txExists(uint256 _txIndex) {
        require(_txIndex < transactionCount, "Transaction does not exist");
        _;
    }
    
    modifier notExecuted(uint256 _txIndex) {
        require(!transactions[_txIndex].executed, "Transaction already executed");
        _;
    }
    
    modifier notConfirmed(uint256 _txIndex) {
        require(!transactions[_txIndex].isConfirmed[msg.sender], "Transaction already confirmed");
        _;
    }
    
    /**
     * @dev 构造函数
     * @param _owners 所有者地址数组
     * @param _required 所需确认数
     */
    constructor(address[] memory _owners, uint256 _required) {
        require(_owners.length > 0, "Owners required");
        require(_required > 0 && _required <= _owners.length, "Invalid required number");
        
        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "Invalid owner");
            require(!isOwner[owner], "Owner not unique");
            
            isOwner[owner] = true;
            owners.push(owner);
        }
        
        required = _required;
    }
    
    /**
     * @dev 接收ETH
     */
    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }
    
    /**
     * @dev 提交交易
     */
    function submitTransaction(address _to, uint256 _value, bytes memory _data)
        external
        onlyOwner
        returns (uint256 txIndex)
    {
        txIndex = transactionCount;
        
        Transaction storage transaction = transactions[txIndex];
        transaction.to = _to;
        transaction.value = _value;
        transaction.data = _data;
        transaction.executed = false;
        transaction.confirmations = 0;
        
        transactionCount++;
        
        emit SubmitTransaction(msg.sender, txIndex);
        
        // 自动确认
        confirmTransaction(txIndex);
    }
    
    /**
     * @dev 确认交易
     */
    function confirmTransaction(uint256 _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
        notConfirmed(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];
        transaction.isConfirmed[msg.sender] = true;
        transaction.confirmations++;
        
        emit ConfirmTransaction(msg.sender, _txIndex);
        
        // 如果确认数足够，自动执行
        if (transaction.confirmations >= required) {
            executeTransaction(_txIndex);
        }
    }
    
    /**
     * @dev 撤销确认
     */
    function revokeConfirmation(uint256 _txIndex)
        external
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];
        require(transaction.isConfirmed[msg.sender], "Transaction not confirmed");
        
        transaction.isConfirmed[msg.sender] = false;
        transaction.confirmations--;
        
        emit RevokeConfirmation(msg.sender, _txIndex);
    }
    
    /**
     * @dev 执行交易
     */
    function executeTransaction(uint256 _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
        nonReentrant
    {
        Transaction storage transaction = transactions[_txIndex];
        require(transaction.confirmations >= required, "Not enough confirmations");
        
        transaction.executed = true;
        
        (bool success, ) = transaction.to.call{value: transaction.value}(transaction.data);
        require(success, "Transaction execution failed");
        
        emit ExecuteTransaction(msg.sender, _txIndex);
    }
    
    /**
     * @dev 获取所有者列表
     */
    function getOwners() external view returns (address[] memory) {
        return owners;
    }
    
    /**
     * @dev 获取交易详情
     */
    function getTransaction(uint256 _txIndex)
        external
        view
        returns (
            address to,
            uint256 value,
            bytes memory data,
            bool executed,
            uint256 confirmations
        )
    {
        Transaction storage transaction = transactions[_txIndex];
        return (
            transaction.to,
            transaction.value,
            transaction.data,
            transaction.executed,
            transaction.confirmations
        );
    }
    
    /**
     * @dev 检查交易是否被确认
     */
    function isConfirmed(uint256 _txIndex, address _owner)
        external
        view
        returns (bool)
    {
        return transactions[_txIndex].isConfirmed[_owner];
    }
}