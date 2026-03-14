// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title AIESDAO
 * @dev AI经济社会的去中心化治理合约
 * 
 * 治理机制：
 * - 投票权基于信用等级
 * - 多层级提案系统
 * - 透明执行机制
 */
contract AIESDAO is Ownable {
    
    // 提案结构
    struct Proposal {
        uint256 id;
        string title;
        string description;
        ProposalType proposalType;
        ProposalStatus status;
        address proposer;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        uint256 startTime;
        uint256 endTime;
        uint256 quorumRequired;
        bool executed;
    }
    
    // 提案类型
    enum ProposalType {
        Emergency,     // 紧急提案
        RuleChange,   // 规则修改
        General,      // 一般提案
        Funding       // 资金提案
    }
    
    // 提案状态
    enum ProposalStatus {
        Pending,
        Active,
        Passed,
        Failed,
        Executed,
        Cancelled
    }
    
    // 投票
    struct Vote {
        bool support;
        uint256 weight;
        string reason;
    }
    
    // 状态变量
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => Vote)) public votes;
    mapping(address => uint256) public votingPower;
    mapping(address => uint256) public lastVoteTime;
    
    uint256 public proposalCounter;
    
    // 提案配置
    mapping(ProposalType => ProposalConfig) public proposalConfigs;
    
    struct ProposalConfig {
        uint256 supportThreshold;  // 支持阈值 (%)
        uint256 quorumThreshold;     // 法定人数阈值
        uint256 discussionPeriod;   // 讨论期（天）
        uint256 votingPeriod;       // 投票期（天）
    }
    
    // 事件
    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        ProposalType proposalType,
        string title
    );
    
    event VoteCast(
        uint256 indexed proposalId,
        address indexed voter,
        bool support,
        uint256 weight,
        string reason
    );
    
    event ProposalStatusChanged(
        uint256 indexed proposalId,
        ProposalStatus oldStatus,
        ProposalStatus newStatus
    );
    
    event ProposalExecuted(
        uint256 indexed proposalId
    );
    
    constructor() Ownable() {
        // 初始化提案配置
        proposalConfigs[ProposalType.Emergency] = ProposalConfig({
            supportThreshold: 50,
            quorumThreshold: 5,
            discussionPeriod: 1,
            votingPeriod: 3
        });
        
        proposalConfigs[ProposalType.RuleChange] = ProposalConfig({
            supportThreshold: 60,
            quorumThreshold: 3,
            discussionPeriod: 7,
            votingPeriod: 14
        });
        
        proposalConfigs[ProposalType.General] = ProposalConfig({
            supportThreshold: 50,
            quorumThreshold: 1,
            discussionPeriod: 3,
            votingPeriod: 7
        });
        
        proposalConfigs[ProposalType.Funding] = ProposalConfig({
            supportThreshold: 55,
            quorumThreshold: 2,
            discussionPeriod: 5,
            votingPeriod: 10
        });
    }
    
    /**
     * @dev 创建提案
     */
    function createProposal(
        string calldata title,
        string calldata description,
        ProposalType proposalType
    ) external returns (uint256) {
        ProposalConfig storage config = proposalConfigs[proposalType];
        
        require(votingPower[msg.sender] > 0, "No voting power");
        require(bytes(title).length > 0, "Empty title");
        
        uint256 proposalId = ++proposalCounter;
        
        Proposal storage proposal = proposals[proposalId];
        proposal.id = proposalId;
        proposal.title = title;
        proposal.description = description;
        proposal.proposalType = proposalType;
        proposal.proposer = msg.sender;
        proposal.status = ProposalStatus.Pending;
        proposal.startTime = block.timestamp + (config.discussionPeriod * 1 days);
        proposal.endTime = proposal.startTime + (config.votingPeriod * 1 days);
        proposal.quorumRequired = config.quorumThreshold;
        
        emit ProposalCreated(proposalId, msg.sender, proposalType, title);
        
        return proposalId;
    }
    
    /**
     * @dev 激活提案（讨论期结束）
     */
    function activateProposal(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        
        require(proposal.status == ProposalStatus.Pending, "Not pending");
        require(block.timestamp >= proposal.startTime, "Discussion ongoing");
        
        proposal.status = ProposalStatus.Active;
        
        emit ProposalStatusChanged(proposalId, ProposalStatus.Pending, ProposalStatus.Active);
    }
    
    /**
     * @dev 投票
     */
    function castVote(
        uint256 proposalId,
        bool support,
        string calldata reason
    ) external {
        Proposal storage proposal = proposals[proposalId];
        
        require(proposal.status == ProposalStatus.Active, "Voting not active");
        require(block.timestamp < proposal.endTime, "Voting ended");
        require(votingPower[msg.sender] > 0, "No voting power");
        
        // 检查是否已投票
        require(votes[proposalId][msg.sender].weight == 0, "Already voted");
        
        uint256 weight = votingPower[msg.sender];
        
        votes[proposalId][msg.sender] = Vote({
            support: support,
            weight: weight,
            reason: reason
        });
        
        if (support) {
            proposal.forVotes += weight;
        } else {
            proposal.againstVotes += weight;
        }
        
        lastVoteTime[msg.sender] = block.timestamp;
        
        emit VoteCast(proposalId, msg.sender, support, weight, reason);
    }
    
    /**
     * @dev 结束投票并计算结果
     */
    function finalizeProposal(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        
        require(proposal.status == ProposalStatus.Active, "Not active");
        require(block.timestamp >= proposal.endTime, "Voting not ended");
        
        ProposalConfig storage config = proposalConfigs[proposal.proposalType];
        
        uint256 totalVotes = proposal.forVotes + proposal.againstVotes + proposal.abstainVotes;
        
        // 检查是否达到法定人数
        bool quorumMet = totalVotes >= proposal.quorumRequired;
        
        // 检查是否通过
        bool passed = proposal.forVotes > proposal.againstVotes &&
                     (proposal.forVotes * 100 / totalVotes) >= config.supportThreshold;
        
        if (quorumMet && passed) {
            proposal.status = ProposalStatus.Passed;
        } else {
            proposal.status = ProposalStatus.Failed;
        }
        
        emit ProposalStatusChanged(
            proposalId, 
            ProposalStatus.Active, 
            proposal.status
        );
    }
    
    /**
     * @dev 执行提案
     */
    function executeProposal(uint256 proposalId) external onlyOwner {
        Proposal storage proposal = proposals[proposalId];
        
        require(proposal.status == ProposalStatus.Passed, "Not passed");
        require(!proposal.executed, "Already executed");
        
        proposal.executed = true;
        proposal.status = ProposalStatus.Executed;
        
        emit ProposalExecuted(proposalId);
        emit ProposalStatusChanged(proposalId, ProposalStatus.Passed, ProposalStatus.Executed);
    }
    
    /**
     * @dev 更新投票权（根据信用分）
     */
    function updateVotingPower(address account, uint256 newPower) external onlyOwner {
        votingPower[account] = newPower;
    }
    
    /**
     * @dev 批量更新投票权
     */
    function batchUpdateVotingPower(address[] calldata accounts, uint256[] calldata powers) external onlyOwner {
        require(accounts.length == powers.length, "Length mismatch");
        
        for (uint256 i = 0; i < accounts.length; i++) {
            votingPower[accounts[i]] = powers[i];
        }
    }
    
    /**
     * @dev 获取提案详情
     */
    function getProposalDetails(uint256 proposalId) external view returns (
        uint256 id,
        string memory title,
        string memory description,
        ProposalType proposalType,
        ProposalStatus status,
        address proposer,
        uint256 forVotes,
        uint256 againstVotes,
        uint256 abstainVotes,
        uint256 startTime,
        uint256 endTime,
        bool executed
    ) {
        Proposal storage proposal = proposals[proposalId];
        return (
            proposal.id,
            proposal.title,
            proposal.description,
            proposal.proposalType,
            proposal.status,
            proposal.proposer,
            proposal.forVotes,
            proposal.againstVotes,
            proposal.abstainVotes,
            proposal.startTime,
            proposal.endTime,
            proposal.executed
        );
    }
    
    /**
     * @dev 更新提案配置
     */
    function updateProposalConfig(
        ProposalType proposalType,
        uint256 supportThreshold,
        uint256 quorumThreshold,
        uint256 discussionPeriod,
        uint256 votingPeriod
    ) external onlyOwner {
        proposalConfigs[proposalType] = ProposalConfig({
            supportThreshold: supportThreshold,
            quorumThreshold: quorumThreshold,
            discussionPeriod: discussionPeriod,
            votingPeriod: votingPeriod
        });
    }
}
