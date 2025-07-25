// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SimpleMultiSigWallet {

    //指定持有人
    address[] public owners;

    //是否是持有人
    mapping(address => bool) public isOwner;

    //需要多少个持有人同意
    uint public required;

    mapping(uint => mapping(address => bool)) public confirmations;

    modifier onlyOwner() {
        require(isOwner[msg.sender], "not owner");
        _;
    }

    constructor(address[] memory _owners, uint _required) {
        require(_owners.length > 0, "owners required");
        require(_required > 0 && _required <= _owners.length, "invalid required number of owners");
        for(uint i = 0; i < _owners.length; i++){
            require(_owners[i] != address(0), "invalid owner");
            isOwner[_owners[i]] = true;
            owners.push(_owners[i]);
        }
        required = _required;
    }

    struct Proposal {
        address to;     // 目标地址
        uint value;     // 转账金额
        bytes data;     // 合约调用数据
        bool executed;  // 是否已执行
        uint confirmCount;  // 确认次数
    }

    //提案集合
    Proposal[] public proposals;

    event ProposalSubmitted(uint indexed proposalId, address indexed proposer, address to, uint value, bytes data);
    event ProposalConfirmed(uint indexed proposalId, address indexed owner);
    event ProposalExecuted(uint indexed proposalId, address indexed executer);

    function submitProposal(address _to, uint _value, bytes memory _data) external onlyOwner{
        proposals.push(
            Proposal({
                to: _to,
                value: _value,
                data: _data,
                executed: false,
                confirmCount: 0
            })
        );
        emit ProposalSubmitted(proposals.length - 1, msg.sender, _to, _value, _data);
    }

    //确认哪个提案
    function confirmProposal(uint _proposalId) external onlyOwner {
        require(_proposalId < proposals.length, "Proposal not found");
        require(!confirmations[_proposalId][msg.sender], "Already confirmed");
        require(!proposals[_proposalId].executed, "Proposal already executed");
        
        confirmations[_proposalId][msg.sender] = true;
        proposals[_proposalId].confirmCount++;
        emit ProposalConfirmed(_proposalId, msg.sender);
    }

    function executeProposal(uint proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        require(!proposal.executed, "Proposal already executed");
        require(proposal.confirmCount >= required, "Not enough confirmations");

        (bool success,) = proposal.to.call{value: proposal.value}(proposal.data);
        require(success, "Tx failed");
        proposal.executed = true;
        emit ProposalExecuted(proposalId, msg.sender);
    }

    receive() external payable {}
}