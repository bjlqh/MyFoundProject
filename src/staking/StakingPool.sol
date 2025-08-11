// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IBank.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);

    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

interface IToken is IERC20 {
    function mint(address to, uint amount) external;
}

interface IStaking {
    //质押ETH到合约
    function stake() external payable;

    //赎回质押ETH
    function unstake(uint amount) external;

    //领取KK Token收益
    function claim() external;

    //获取质押的ETH数量
    function balanceOf(address account) external view returns (uint);

    //获取待领取的KK Token收益
    function earned(address account) external view returns (uint);
}

contract StakingPool is IStaking, ReentrancyGuard {
    IToken public immutable kkToken;
    IBank public immutable bank;

    uint private _totalSupply;
    mapping(address => uint) private _balances;

    uint public constant REWARD_PER_BLOCK = 10 * 1e18; //每个区块的奖励
    uint public lastRewardBlock; //最后更新奖励的区块高度
    uint public accRewardPerShare; //每个质押者的奖励 pershare

    mapping(address => uint) public rewardDebt; //用户当前质押数量所对应的累计奖励

    constructor(address _token, address _bank) {
        kkToken = IToken(_token);
        bank = IBank(_bank);
        lastRewardBlock = block.number;
    }

    event Staked(address indexed user, uint amount);
    event Unstaked(address indexed user, uint amount);
    event Claimed(address indexed user, uint amount);

    function updatePool() public {
        if (block.number <= lastRewardBlock) {
            return;
        }

        //当前合约的质押金额
        uint totalStaked = _totalSupply;

        if (totalStaked == 0) {
            lastRewardBlock = block.number;
            return;
        }

        //经过上次奖励发放后，经过的区块数
        uint blocks = block.number - lastRewardBlock;

        //总的应该放发的奖励数
        uint rewards = blocks * REWARD_PER_BLOCK;
        //每一份质押份额累计获得奖励总量（是一个累计值）
        accRewardPerShare += (rewards * 1e12) / totalStaked;
        lastRewardBlock = block.number;
    }

    function stake() public payable override {
        require(msg.value > 0, "Cannot stake 0");
        updatePool();

        // 如果用户已有质押，先领取之前的奖励
        if (_balances[msg.sender] > 0) {
            uint pending = earned(msg.sender);
            if (pending > 0) {
                kkToken.mint(msg.sender, pending);
                emit Claimed(msg.sender, pending);
            }
        }

        //质押资金
        _balances[msg.sender] += msg.value;
        _totalSupply += msg.value;
        //用户当前质押所对应的累计奖励
        rewardDebt[msg.sender] =
            (_balances[msg.sender] * accRewardPerShare) /
            1e12;

        //bank才是真正管理用户质押资产的地方
        bank.deposit{value: msg.value}();
    
        emit Staked(msg.sender, msg.value);
    }

    function unstake(uint amount) public override {
        require(amount > 0, "Cannot unstake 0");
        require(_balances[msg.sender] >= amount, "Not enough balance");
        updatePool();
        claim();
        _balances[msg.sender] -= amount;
        _totalSupply -= amount;
        rewardDebt[msg.sender] =
            (_balances[msg.sender] * accRewardPerShare) /
            1e12;
        //资金质押在bank中，所以应该从bank中提现
        bank.withdrawTo(amount, msg.sender);

        emit Unstaked(msg.sender, amount);
    }

    function claim() public override {
        uint pending = earned(msg.sender);
        if (pending > 0) {
            kkToken.mint(msg.sender, pending);
        }
        rewardDebt[msg.sender] =
            (_balances[msg.sender] * accRewardPerShare) /
            1e12;

        emit Claimed(msg.sender, pending);
    }

    function balanceOf(address account) public view override returns (uint) {
        return _balances[account];
    }

    //计算某个账户当前可领取的奖惩
    function earned(address account) public view override returns (uint) {
        //当前账户质押对应的累计奖励-之前已经结算过的奖励=账户当前可领取的新奖励
        uint currentAccRewardPerShare = accRewardPerShare;
        
        //计算当前区块的实时奖励
        if(block.number > lastRewardBlock && _totalSupply > 0){
            uint blocks = block.number - lastRewardBlock;
            uint rewards = blocks * REWARD_PER_BLOCK;
            currentAccRewardPerShare += (rewards * 1e12) / _totalSupply;
        }
        return
            ((_balances[account] * currentAccRewardPerShare) / 1e12) -
            rewardDebt[account];
    }

    receive() external payable {
        stake();
    }
}
