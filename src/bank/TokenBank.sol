// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "../MyToken.sol";
import {Permit2} from "@permit2/Permit2.sol";
import {IAllowanceTransfer} from "@permit2/interfaces/IAllowanceTransfer.sol";

contract TokenBank {

    mapping (address => uint256) public balances;

    //address private tokenAddress;
    MyToken private token;
    
    // Permit2 合约地址
    // MyPermit2 public permit2;
    Permit2 public permit2;

    constructor(address _tokenAddress, address _permit2Address){
        token = MyToken(_tokenAddress);
        if(_permit2Address != address(0)){
            //permit2 = MyPermit2(_permit2Address);
            permit2 = Permit2(_permit2Address);
        }
    }

    //记录每个地址存的数量
    function deposit(uint amount) public {
        require(amount > 0, "amount must be greater than 0");

        //转移token到当前合约
        bool success = token.transferFrom(msg.sender, address(this), amount);
        require(success, "failed to transferFrom");

        //记录
        balances[msg.sender] += amount;
    }

    // 使用permit进行离线签名授权存款
    function permitDeposit(
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        require(amount > 0, "amount must be greater than 0");
        require(deadline >= block.timestamp, "permit expired");

        // 使用permit授权
        token.permit(msg.sender, address(this), amount, deadline, v, r, s);
        
        // 转移token到当前合约
        bool success = token.transferFrom(msg.sender, address(this), amount);
        require(success, "failed to transferFrom");

        // 记录
        balances[msg.sender] += amount;
    }

    /**
     * permit2 离线签名授权存款
     * 使用 Permit2 进行签名授权转账来进行存款
     * 与 permit 的区别：
     * 1. Permit2 是 Uniswap 开发的统一授权标准
     * 2. 支持批量授权和转账
     * 3. 更高效的 gas 使用
     * 4. 更好的用户体验
     */
    function depositWithPermit2(
        address owner,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        require(amount > 0, "amount must be greater than 0");
        require(deadline >= block.timestamp, "permit expired");

        (,, uint48 nonce) = permit2.allowance(owner, address(token), address(this));
        
        IAllowanceTransfer.PermitSingle memory permitSingle = IAllowanceTransfer.PermitSingle({
            details: IAllowanceTransfer.PermitDetails({
                token: address(token),
                amount: uint160(amount),
                expiration: uint48(deadline),
                nonce: nonce
            }),
            spender: address(this),
            sigDeadline: deadline
        });

        // 验证签名并设置授权
        permit2.permit(owner, permitSingle, abi.encodePacked(r, s, v));
        
        // 使用 Permit2 转移代币到当前合约
        permit2.transferFrom(owner, address(this), uint160(amount), address(token));

        // 记录存款
        balances[owner] += amount;
    }

    /**
     * 使用 Permit2 进行批量存款
     * 支持一次性授权多个代币
     */
    function depositWithPermit2Batch(
        address owner,
        uint256 amount,
        uint256 deadline,
        bytes calldata signature
    ) public {
        require(amount > 0, "amount must be greater than 0");
        require(deadline >= block.timestamp, "permit expired");

        (,, uint48 nonce) = permit2.allowance(owner, address(token), address(this));
        IAllowanceTransfer.PermitSingle memory permitSingle = IAllowanceTransfer.PermitSingle({
            details: IAllowanceTransfer.PermitDetails({
                token: address(token),
                amount: uint160(amount),
                expiration: uint48(deadline),
                nonce: nonce
            }),
            spender: address(this),
            sigDeadline: deadline
        });

        // 验证签名并设置授权
        permit2.permit(owner, permitSingle, signature);
        
        // 使用 Permit2 转移代币到当前合约
        permit2.transferFrom(owner, address(this), uint160(amount), address(token));

        // 记录存款
        balances[owner] += amount;
    }

    /**
     * 获取用户的 Permit2 nonce
     * 用于生成正确的签名
     */
    function getPermit2Nonce(address owner) public view returns (uint48) {
        (,, uint48 nonce) = permit2.allowance(owner, address(token), address(this));
        return nonce;
    }

    /**
     * 检查用户是否已授权 Permit2
     * 用户需要先调用 token.approve(permit2Address, amount) 来授权 Permit2
     */
    function checkPermit2Approval(address owner, uint256 amount) public view returns (bool) {
        return token.allowance(owner, address(permit2)) >= amount;
    }

    //用户可以提取自己存的token
    function withdraw(uint amount) public {
        require(amount > 0, "amount must be greater than 0");
        require(balances[msg.sender] >= amount, "Insufficient Balance");

        balances[msg.sender] -= amount;
        bool succ = token.transfer(msg.sender, amount);

        require(succ, "failed to transfer");
    }

}