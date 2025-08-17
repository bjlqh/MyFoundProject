// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./IUniswapV2.sol";

contract UniswapV2Factory {
    address public feeTo;       // 手续费接收地址
    address public feeToSetter; // 设置手续费接收地址的管理员

    // 代币对到交易对地址的映射
    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;      //已创建交易对的数组

    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    constructor(address _feeToSetter) {
        feeToSetter = _feeToSetter;
    }

    function allPairsLength() external view returns (uint) {
        return allPairs.length;
    }

    function createPair(address tokenA, address tokenB) external returns (address pair) {
        require(tokenA != tokenB, 'UniswapV2: IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'UniswapV2: ZERO_ADDRESS');
        require(getPair[token0][token1] == address(0), 'UniswapV2: PAIR_EXISTS');
        //返回UniswapV2Pair合约的字节码
        bytes memory bytecode = type(UniswapV2Pair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            //create2操作码进行确定性部署
            //0: 发送的ETH数量，add(bytecode, 32)指向字节码的起始位置，mload(bytecode)获取字节码的长度,salt盐值
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        IUniswapV2PairSimple(pair).initialize(token0, token1);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair;
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setFeeTo(address _feeTo) external {
        require(msg.sender == feeToSetter, 'UniswapV2: FORBIDDEN');
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external {
        require(msg.sender == feeToSetter, 'UniswapV2: FORBIDDEN');
        feeToSetter = _feeToSetter;
    }
    
    // 添加这个函数用于获取 INIT_CODE_HASH
    function INIT_CODE_HASH() external pure returns (bytes32) {
        return keccak256(abi.encodePacked(type(UniswapV2Pair).creationCode));
    }
}

// 简化版的 UniswapV2Pair 合约
contract UniswapV2Pair {
    address public factory;
    address public token0;
    address public token1;

    uint112 private reserve0;
    uint112 private reserve1;
    uint32  private blockTimestampLast;

    uint public constant MINIMUM_LIQUIDITY = 10**3;
    bytes4 private constant SELECTOR = bytes4(keccak256(bytes('transfer(address,uint256)')));

    mapping(address => uint) public balanceOf;
    mapping(address => mapping(address => uint)) public allowance;
    uint public totalSupply;

    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);
    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    constructor() {
        factory = msg.sender;
    }

    function initialize(address _token0, address _token1) external {
        require(msg.sender == factory, 'UniswapV2: FORBIDDEN');
        token0 = _token0;
        token1 = _token1;
    }

    function getReserves() public view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    /**
     * 将代币从Uniswap池子转给指定地址
     * @param token 要转出的代币合约地址
     * @param to 接收代币的地址(通常是套利合约或者用户地址)
     * @param value 要转出的代币数量
     */
    function _safeTransfer(address token, address to, uint value) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'UniswapV2: TRANSFER_FAILED');
    }

    function _update(uint balance0, uint balance1, uint112 _reserve0, uint112 _reserve1) private {
        require(balance0 <= type(uint112).max && balance1 <= type(uint112).max, 'UniswapV2: OVERFLOW');
        uint32 blockTimestamp = uint32(block.timestamp % 2**32);
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = blockTimestamp;
        emit Sync(reserve0, reserve1);
    }

    function _mint(address to, uint value) internal {
        totalSupply += value;
        balanceOf[to] += value;
        emit Transfer(address(0), to, value);
    }

    function _burn(address from, uint value) internal {
        balanceOf[from] -= value;
        totalSupply -= value;
        emit Transfer(from, address(0), value);
    }

    /**
     * 铸造流动性代币  -为流动性提供添加流动性
     * @param to 接收流动性代币的地址
     * @return liquidity 铸造的流动性代币数量
     * 工作原理：
     * 1. 计算用户实际存入的代币的数量（当前余额-存储量）
     * 2. 如果是首次添加流动性，使用集合平均数计算流动性
     * 3. 如果不是首次，按比例计算流动性（取较小值防止价格操纵）
     * 4. 铸造流动性代币给流动性提供者
     */
    function mint(address to) external returns (uint liquidity) {
        // 获取当前储备量
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        // 获取合约当前的代币余额
        uint balance0 = IERC20Simple(token0).balanceOf(address(this));
        uint balance1 = IERC20Simple(token1).balanceOf(address(this));
        // 计算新增的代币数量
        uint amount0 = balance0 - _reserve0;
        uint amount1 = balance1 - _reserve1;

        uint _totalSupply = totalSupply;
        if (_totalSupply == 0) {
            //首次添加流动性：使用集合平均数是计算流动性
            liquidity = sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            //锁定最小流动性防止攻击
           _mint(address(0), MINIMUM_LIQUIDITY);
        } else {
            //后续添加流动性：按比例计算，取较小值确保价格不被操纵
            liquidity = min(amount0 * _totalSupply / _reserve0, amount1 * _totalSupply / _reserve1);
        }
        require(liquidity > 0, 'UniswapV2: INSUFFICIENT_LIQUIDITY_MINTED');
        // 铸造LP代币给流动性提供者
        _mint(to, liquidity);

        // 更新存储量
        _update(balance0, balance1, _reserve0, _reserve1);
        emit Mint(msg.sender, amount0, amount1);
    }

    /**
     * 销毁流动性代币 为流动性提供者移除流动性
     * @param to 接收底层代币地址
     * @return amount0 返还的token0数量
     * @return amount1 返还的token1数量
     * 工作原理：
     * 1.根据LP代币占总供应量的比例计算返还的代币数量
     * 2.销毁相应的LP代币
     * 3.将计算出的代币数量转账给指定地址
     */
    function burn(address to) external returns (uint amount0, uint amount1) {
        // 获取当前储备量
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        address _token0 = token0;
        address _token1 = token1;
        // 获取合约当前的代币余额
        uint balance0 = IERC20Simple(_token0).balanceOf(address(this));
        uint balance1 = IERC20Simple(_token1).balanceOf(address(this));
        // 获取当前合约中的LP代币数量（需要销毁的数量）
        uint liquidity = balanceOf[address(this)];

        uint _totalSupply = totalSupply;
        // 按比例计算应返还的代币数量
        // 公式：返还数量 = (LP代币数量 / 总LP供应量) * 代币余额
        amount0 = liquidity * balance0 / _totalSupply;
        amount1 = liquidity * balance1 / _totalSupply;
        require(amount0 > 0 && amount1 > 0, 'UniswapV2: INSUFFICIENT_LIQUIDITY_BURNED');
        // 销毁LP代币
        _burn(address(this), liquidity);
        // 将代币转账给指定账户
        _safeTransfer(_token0, to, amount0);
        _safeTransfer(_token1, to, amount1);
        // 重新获取余额(转账后的余额)
        balance0 = IERC20Simple(_token0).balanceOf(address(this));
        balance1 = IERC20Simple(_token1).balanceOf(address(this));

        // 更新储备量
        _update(balance0, balance1, _reserve0, _reserve1);
        emit Burn(msg.sender, amount0, amount1, to);
    }

    /**
     * 代币交换函数 支持普通交换和闪电兑换
     * @param amount0Out 输出的token0数量
     * @param amount1Out 输出的token1数量
     * @param to 接收代币的地址
     * @param data 回调数据，如果不为空则触发闪电兑换
     * 
     * 闪电兑换原理：
     * 1. 先将代币转给接收方（借出）
     * 2. 如果有回调数据，调用接收方的回调函数
     * 3. 在回调中，接收方可以使用借出的代币进行套利等操作
     * 4. 回调结束后，验证是否收到足够的输入代币(还款)
     * 5. 验证恒定乘积公式，确保交易合法
     */
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external {
        require(amount0Out > 0 || amount1Out > 0, 'UniswapV2: INSUFFICIENT_OUTPUT_AMOUNT');
        // 获取当前储备量
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        // 确保输出量不会超过储备量
        require(amount0Out < _reserve0 && amount1Out < _reserve1, 'UniswapV2: INSUFFICIENT_LIQUIDITY');

        uint balance0;
        uint balance1;
        {
        address _token0 = token0;
        address _token1 = token1;
        // 确保接收地址不是代币合约地址
        require(to != _token0 && to != _token1, 'UniswapV2: INVALID_TO');
        // 先转账代币给接收方(闪电兑换的关键：先借出)
        if (amount0Out > 0) _safeTransfer(_token0, to, amount0Out);
        if (amount1Out > 0) _safeTransfer(_token1, to, amount1Out);
        // 如果有回调数据，执行闪电兑换回调
        if (data.length > 0) IUniswapV2Callee(to).uniswapV2Call(msg.sender, amount0Out, amount1Out, data);
        // 获取回调后的余额(检查是否收到还款)
        balance0 = IERC20Simple(_token0).balanceOf(address(this));
        balance1 = IERC20Simple(_token1).balanceOf(address(this));
        }
        // 计算实际输入的代币数量，如果余额增加了，说明收到了输入代币
        uint amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
        uint amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;
        require(amount0In > 0 || amount1In > 0, 'UniswapV2: INSUFFICIENT_INPUT_AMOUNT');
        {
        // 计算扣除手续费后的调整余额（0.3%）
        // 公式：调整余额 = 余额 * 1000 - 输入量 * 3
        uint balance0Adjusted = balance0 * 1000 - amount0In * 3;
        uint balance1Adjusted = balance1 * 1000 - amount1In * 3;
        // 验证恒定乘积公式：调账后的乘积 >= 原储备量 * 1000^2 
        // 这确保了交换后的K值不小于交换前(考虑手续费)
        require(balance0Adjusted * balance1Adjusted >= uint(_reserve0) * _reserve1 * (1000**2), 'UniswapV2: K');
        }
        //更新储备量
        _update(balance0, balance1, _reserve0, _reserve1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    function transfer(address to, uint value) external returns (bool) {
        balanceOf[msg.sender] -= value;
        balanceOf[to] += value;
        emit Transfer(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint value) external returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint value) external returns (bool) {
        if (allowance[from][msg.sender] != type(uint).max) {
            allowance[from][msg.sender] -= value;
        }
        balanceOf[from] -= value;
        balanceOf[to] += value;
        emit Transfer(from, to, value);
        return true;
    }

    function sqrt(uint y) internal pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function min(uint x, uint y) internal pure returns (uint z) {
        z = x < y ? x : y;
    }
}