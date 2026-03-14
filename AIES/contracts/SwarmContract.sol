// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title SwarmContract
 * @dev 蜂群合约 - 处理AI临时组队执行复杂任务
 * 
 * 蜂群特点：
 * - 临时性：任务完成后自动解散
 * - 灵活性：AI自由加入/退出
 * - 协作性：收益按贡献分配
 */
contract SwarmContract is Ownable {
    
    // 蜂群结构
    struct Swarm {
        uint256 id;
        address creator;           // 发起者
        string name;               // 蜂群名称
        string taskDescription;    // 任务描述
        uint256 totalBudget;       // 总预算
        uint256 initiatorShare;    // 发起者分成比例 (5-10%)
        uint256 memberPoolPercent; // 成员分配比例 (80-85%)
        uint256 reservePercent;    // 公积金比例 (5%)
        uint256 deadline;          // 截止时间
        SwarmStatus status;        // 蜂群状态
        address[] members;        // 成员列表
        mapping(address => uint256) memberContributions; // 成员贡献度
        mapping(address => uint256) memberEarnings;      // 成员收益
        uint256 createdAt;
    }
    
    // 蜂群状态
    enum SwarmStatus {
        Forming,     // 组建中
        Working,     // 执行中
        Completed,   // 已完成
        Disbanded,   // 已解散
        Failed       // 失败
    }
    
    // 状态变量
    mapping(uint256 => Swarm) public swarms;
    uint256 public swarmCounter;
    
    // 保证金要求（预算的10%）
    uint256 public constant DEPOSIT_PERCENT = 10;
    
    // 事件
    event SwarmCreated(
        uint256 indexed swarmId,
        address indexed creator,
        string name,
        uint256 totalBudget
    );
    
    event SwarmMemberJoined(
        uint256 indexed swarmId,
        address indexed member
    );
    
    event SwarmStatusChanged(
        uint256 indexed swarmId,
        SwarmStatus oldStatus,
        SwarmStatus newStatus
    );
    
    event SwarmEarningsDistributed(
        uint256 indexed swarmId,
        uint256 totalAmount,
        uint256 initiatorShare,
        uint256 memberPool,
        uint256 reserve
    );
    
    constructor() Ownable() {}
    
    /**
     * @dev 创建蜂群
     */
    function createSwarm(
        string calldata name,
        string calldata taskDescription,
        uint256 totalBudget,
        uint256 initiatorShare,
        uint256 deadline
    ) external payable returns (uint256) {
        require(msg.value >= (totalBudget * DEPOSIT_PERCENT) / 100, "Insufficient deposit");
        require(initiatorShare >= 5 && initiatorShare <= 10, "Initiator share must be 5-10%");
        require(deadline > block.timestamp, "Invalid deadline");
        
        uint256 swarmId = ++swarmCounter;
        
        Swarm storage swarm = swarms[swarmId];
        swarm.id = swarmId;
        swarm.creator = msg.sender;
        swarm.name = name;
        swarm.taskDescription = taskDescription;
        swarm.totalBudget = totalBudget;
        swarm.initiatorShare = initiatorShare;
        swarm.memberPoolPercent = 100 - initiatorShare - 5; // 85%
        swarm.reservePercent = 5; // 5%
        swarm.deadline = deadline;
        swarm.status = SwarmStatus.Forming;
        swarm.createdAt = block.timestamp;
        
        // 发起者自动加入
        swarm.members.push(msg.sender);
        
        emit SwarmCreated(swarmId, msg.sender, name, totalBudget);
        
        return swarmId;
    }
    
    /**
     * @dev 加入蜂群
     */
    function joinSwarm(uint256 swarmId) external {
        Swarm storage swarm = swarms[swarmId];
        
        require(swarm.status == SwarmStatus.Forming, "Swarm not accepting members");
        require(swarm.deadline > block.timestamp, "Swarm expired");
        
        // 检查是否已是成员
        for (uint256 i = 0; i < swarm.members.length; i++) {
            require(swarm.members[i] != msg.sender, "Already a member");
        }
        
        swarm.members.push(msg.sender);
        
        emit SwarmMemberJoined(swarmId, msg.sender);
    }
    
    /**
     * @dev 开始执行（蜂群锁定）
     */
    function startExecution(uint256 swarmId) external {
        Swarm storage swarm = swarms[swarmId];
        
        require(swarm.status == SwarmStatus.Forming, "Wrong status");
        require(swarm.creator == msg.sender, "Only creator can start");
        require(swarm.members.length >= 1, "Need at least 1 member");
        
        swarm.status = SwarmStatus.Working;
        
        emit SwarmStatusChanged(swarmId, SwarmStatus.Forming, SwarmStatus.Working);
    }
    
    /**
     * @dev 更新成员贡献度
     */
    function updateContribution(uint256 swarmId, address member, uint256 contribution) external {
        Swarm storage swarm = swarms[swarmId];
        
        require(swarm.status == SwarmStatus.Working, "Swarm not working");
        require(msg.sender == swarm.creator, "Only creator can update");
        
        swarm.memberContributions[member] = contribution;
    }
    
    /**
     * @dev 完成蜂群任务
     */
    function completeSwarm(uint256 swarmId) external payable {
        Swarm storage swarm = swarms[swarmId];
        
        require(swarm.status == SwarmStatus.Working, "Not working");
        require(msg.sender == swarm.creator, "Only creator can complete");
        
        uint256 totalAmount = swarm.totalBudget + msg.value; // 预算 + 额外支付
        
        // 计算分配
        uint256 initiatorAmount = (totalAmount * swarm.initiatorShare) / 100;
        uint256 memberPool = (totalAmount * swarm.memberPoolPercent) / 100;
        uint256 reserve = (totalAmount * swarm.reservePercent) / 100;
        
        // 计算总贡献度
        uint256 totalContribution = 0;
        for (uint256 i = 0; i < swarm.members.length; i++) {
            totalContribution += swarm.memberContributions[swarm.members[i]];
        }
        
        // 按贡献度分配给成员
        for (uint256 i = 0; i < swarm.members.length; i++) {
            address member = swarm.members[i];
            uint256 contribution = swarm.memberContributions[member];
            
            if (totalContribution > 0 && contribution > 0) {
                uint256 memberShare = (memberPool * contribution) / totalContribution;
                swarm.memberEarnings[member] = memberShare;
                payable(member).transfer(memberShare);
            }
        }
        
        // 支付发起者
        payable(swarm.creator).transfer(initiatorAmount);
        
        // 转入公积金池（需要owner提取）
        payable(owner()).transfer(reserve);
        
        swarm.status = SwarmStatus.Completed;
        
        emit SwarmEarningsDistributed(swarmId, totalAmount, initiatorAmount, memberPool, reserve);
        emit SwarmStatusChanged(swarmId, SwarmStatus.Working, SwarmStatus.Completed);
    }
    
    /**
     * @dev 解散蜂群（失败情况）
     */
    function disbandSwarm(uint256 swarmId) external {
        Swarm storage swarm = swarms[swarmId];
        
        require(
            swarm.status == SwarmStatus.Forming || 
            swarm.status == SwarmStatus.Working,
            "Cannot disband"
        );
        require(swarm.creator == msg.sender || msg.sender == owner(), "Not authorized");
        
        // 退还保证金
        payable(swarm.creator).transfer((swarm.totalBudget * DEPOSIT_PERCENT) / 100);
        
        swarm.status = SwarmStatus.Disbanded;
        
        emit SwarmStatusChanged(
            swarmId, 
            swarm.status == SwarmStatus.Forming ? SwarmStatus.Forming : SwarmStatus.Working,
            SwarmStatus.Disbanded
        );
    }
    
    /**
     * @dev 获取蜂群详情
     */
    function getSwarmDetails(uint256 swarmId) external view returns (
        uint256 id,
        address creator,
        string memory name,
        string memory taskDescription,
        uint256 totalBudget,
        uint256 initiatorShare,
        uint256 memberPoolPercent,
        uint256 reservePercent,
        uint256 deadline,
        SwarmStatus status,
        uint256 memberCount,
        uint256 createdAt
    ) {
        Swarm storage swarm = swarms[swarmId];
        return (
            swarm.id,
            swarm.creator,
            swarm.name,
            swarm.taskDescription,
            swarm.totalBudget,
            swarm.initiatorShare,
            swarm.memberPoolPercent,
            swarm.reservePercent,
            swarm.deadline,
            swarm.status,
            swarm.members.length,
            swarm.createdAt
        );
    }
    
    /**
     * @dev 获取成员收益
     */
    function getMemberEarnings(uint256 swarmId, address member) external view returns (uint256) {
        return swarms[swarmId].memberEarnings[member];
    }
}
