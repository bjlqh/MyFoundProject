// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

contract MyPermit2 is EIP712 {
    using ECDSA for bytes32;

    struct PermitDetails {
        address token; //代币地址
        uint160 amount; //授权金额
        uint48 expiration; //授权过期时间 block.timestamp + 1 day:1天后过期
        uint48 nonce; //防止重放攻击
    }

    struct PermitSingle {
        PermitDetails details;
        address spender; //授权TokenBank使用
        uint256 sigDeadline; //签名过期时间 block.timestamp + 1 hour:1小时后过期
    }

    //存储用户的授权信息
    //allowances[用户地址][代币地址][被授权者地址] = 授权金额
    mapping(address => mapping(address => mapping(address => uint256)))
        public allowances;
    //nonces[用户地址][代币地址][被授权者地址] = 当前nonce值
    mapping(address => mapping(address => mapping(address => uint256)))
        public nonces;

    constructor() EIP712("MyPermit2", "1") {}

    //验证签名并授权
    function permit(
        address owner,
        PermitSingle calldata permitSingle,
        bytes calldata signature
    ) external {
        require(block.timestamp <= permitSingle.sigDeadline, "Permit expired");

        //验证签名
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256(
                    "PermitDetails(address token, uint160 amount, uint48 expiration, uint48 nonce)"
                ),
                permitSingle.details.token,
                permitSingle.details.amount,
                permitSingle.details.expiration,
                permitSingle.details.nonce
            )
        );

        bytes32 hash = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    keccak256(
                        "PermitSingle(PermitDetails details, address spender, uint256 sigDeadline)"
                    ),
                    structHash,
                    permitSingle.spender,
                    permitSingle.sigDeadline
                )
            )
        );

        address signer = hash.recover(signature);
        require(signer == owner, "Invalid signature");

        //验证nonce
        require(
            nonces[owner][permitSingle.details.token][permitSingle.spender] ==
                permitSingle.details.nonce,
            "Invalid nonce"
        );
        nonces[owner][permitSingle.details.token][permitSingle.spender]++;

        //设置授权
        allowances[owner][permitSingle.details.token][
            permitSingle.spender
        ] = permitSingle.details.amount;
    }

    //使用授权代币（需要预先设置approve）
    function transferFrom(
        address from,
        address to,
        uint160 amount,
        address token
    ) external {
        require(
            allowances[from][token][msg.sender] >= amount,
            "Insufficient allowance"
        );

        //减少授权额度
        allowances[from][token][msg.sender] -= amount;

        //转账
        bool success = ERC20(token).transferFrom(from, to, amount);
        require(success, "Transfer failed");
    }

    //真正的 Permit2 方式：直接签名转移（无需预先 approve）
    function transferFromWithSignature(
        address from,
        address to,
        uint160 amount,
        address token,
        uint256 deadline,
        bytes calldata signature
    ) external {
        require(block.timestamp <= deadline, "Signature expired");
        
        //验证签名
        bytes32 hash = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    keccak256("Transfer(address from,address to,uint160 amount,address token,uint256 deadline)"),
                    from,
                    to,
                    amount,
                    token,
                    deadline
                )
            )
        );
        
        address signer = hash.recover(signature);
        require(signer == from, "Invalid signature");
        
        //直接转移代币
        bool success = ERC20(token).transferFrom(from, to, amount);
        require(success, "Transfer failed");
    }

    //获取用户nonce
    function getNonce(
        address owner,
        address token,
        address spender
    ) external view returns (uint256) {
        return nonces[owner][token][spender];
    }

    //获取用户授权额度
    function getAllowance(
        address owner,
        address token,
        address spender
    ) external view returns (uint256) {
        return allowances[owner][token][spender];
    }
}
