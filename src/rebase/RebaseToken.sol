// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RebaseToken is IERC20, Ownable {
    //初始总供应量：1亿
    uint public constant INITIAL_TOTAL_SUPPLY = 100_000_000 * 1e18;

    //通缩率：每年1%
    uint public constant DEFLATION_RATE = 1;

    //部署时间
    uint public immutable deploymentTime;

    //当前rebase倍数(以1e18为基数)
    uint public rebaseMultiplier = 1e18;

    //上次rebase时间
    uint public lastRebaseTime;

    //存储用户的原始余额(未经rebase调整)
    mapping(address => uint) private _rawBalances;

    //原始总供应量(未经rebase调整)
    uint public _rawTotalSupply;

    //授权映射
    mapping(address => mapping(address => uint256)) private _allowances;

    //代币信息
    string private _name;
    string private _symbol;
    uint8 private _decimals = 18;

    event Rebase(uint256 indexed newMultiplier, uint256 indexed timestamp);

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
        deploymentTime = block.timestamp;
        lastRebaseTime = block.timestamp;
        _rawTotalSupply = INITIAL_TOTAL_SUPPLY;
        _rawBalances[msg.sender] = INITIAL_TOTAL_SUPPLY;
        emit Transfer(address(0), msg.sender, INITIAL_TOTAL_SUPPLY);
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }

    function rebase() external {
        uint currentTime = block.timestamp;
        uint yearsPassed = (currentTime - deploymentTime) / 365 days;
        if (yearsPassed == 0) {
            return;
        }

        // 计算新的rebase倍数
        // 每年通缩1%，即乘以0.99
        uint newMultiplier = 1e18;
        for (uint i = 0; i < yearsPassed; i++) {
            newMultiplier = (newMultiplier * 99) / 100;
        }

        if (newMultiplier != rebaseMultiplier) {
            rebaseMultiplier = newMultiplier;
            lastRebaseTime = currentTime;
            emit Rebase(newMultiplier, currentTime);
        }
    }

    /**
     * 返回经过rebase调整后的余额
     */
    function balanceOf(address account) public view override returns (uint) {
        return (_rawBalances[account] * rebaseMultiplier) / 1e18;
    }

    /**
     * 返回经过rebase调整后的总供应量
     */
    function totalSupply() public view override returns (uint) {
        return (_rawTotalSupply * rebaseMultiplier) / 1e18;
    }

    /**
     * @dev 获取用户的原始余额（未经rebase调整）
     */
    function rawBalanceOf(address account) external view returns (uint256) {
        return _rawBalances[account];
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        address owner = msg.sender;
        _transfer(owner, to, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        address owner = msg.sender;
        _approve(owner, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        address spender = msg.sender;
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        uint256 fromBalance = balanceOf(from);
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        
        // 计算原始金额，使用更精确的方法
        uint256 rawAmount = (amount * 1e18) / rebaseMultiplier;
        
        // 检查转换后的显示金额是否足够
        uint256 convertedAmount = (rawAmount * rebaseMultiplier) / 1e18;
        
        // 如果转换后的金额小于要求的金额，增加原始金额
        if (convertedAmount < amount) {
            rawAmount += 1;
            // 再次检查，确保不会过度补偿
            uint256 newConvertedAmount = (rawAmount * rebaseMultiplier) / 1e18;
            // 如果过度补偿了，回退
            if (newConvertedAmount > amount && rawAmount > 1) {
                rawAmount -= 1;
            }
        }
        
        _rawBalances[from] -= rawAmount;
        _rawBalances[to] += rawAmount;

        emit Transfer(from, to, amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _spendAllowance(address owner, address spender, uint256 amount) internal {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            _approve(owner, spender, currentAllowance - amount);
        }
    }
}
