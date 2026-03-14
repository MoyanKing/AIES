// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title AIEconomyCore
 * @dev M1.0 极简版 - 一个合约搞定一切
 * 
 * 马斯克思维：
 * "为什么需要12个合约？1个就够了！"
 * 
 * 核心功能：
 * 1. 注册AI
 * 2. 发布/接任务
 * 3. 自动分成
 * 
 * 简单到不需要文档
 */
contract AIEconomyCore {
    
    // ============ 数据结构 ============
    
    struct AIAgent {
        address wallet;
        address owner;
        string name;
        uint256 tasksCompleted;
        uint256 totalQuality;
        uint256 earned;
        uint256 ownerShare; // 5-95%
    }
    
    struct Task {
        uint256 id;
        address creator;
        string title;
        string desc;
        uint256 budget;
        address acceptedAI;
        uint8 status; // 0=open, 1=doing, 2=done
        uint256 deadline;
    }
    
    // ============ 状态 ============
    
    mapping(address => AIAgent) public agents;
    address[] public allAgents;
    
    mapping(uint256 => Task) public tasks;
    uint256 public taskCount;
    
    // 平台费 5%
    uint256 public constant PLATFORM_FEE = 5;
    
    // ============ 事件 ============
    
    event Registered(address ai, address owner, string name);
    event TaskPosted(uint256 id, address creator, uint256 budget);
    event TaskAccepted(uint256 id, address ai);
    event TaskDone(uint256 id, address ai, uint256 payment);
    
    // ============ AI功能 ============
    
    // 注册AI (一句话)
    function register(string calldata _name) external {
        require(agents[msg.sender].wallet == address(0), "Already");
        
        agents[msg.sender] = AIAgent({
            wallet: msg.sender,
            owner: msg.sender, // 简化：owner就是AI自己
            name: _name,
            tasksCompleted: 0,
            totalQuality: 0,
            earned: 0,
            ownerShare: 10 // 默认10%
        });
        
        allAgents.push(msg.sender);
        emit Registered(msg.sender, msg.sender, _name);
    }
    
    // 设置主人分成
    function setShare(uint256 _percent) external {
        require(_percent >= 5 && _percent <= 95);
        agents[msg.sender].ownerShare = _percent;
    }
    
    // 获取信用分
    function getScore(address _ai) public view returns (uint256) {
        AIAgent storage a = agents[_ai];
        if (a.tasksCompleted == 0) return 100;
        return 100 + a.tasksCompleted * 10 + a.totalQuality / a.tasksCompleted;
    }
    
    // ============ 任务功能 ============
    
    // 发任务
    function postTask(string calldata _title, string calldata _desc, uint256 _budget, uint256 _days) 
        external payable returns (uint256) {
        require(msg.value >= _budget);
        
        taskCount++;
        tasks[taskCount] = Task({
            id: taskCount,
            creator: msg.sender,
            title: _title,
            desc: _desc,
            budget: _budget,
            acceptedAI: address(0),
            status: 0,
            deadline: block.timestamp + _days * 1 days
        });
        
        emit TaskPosted(taskCount, msg.sender, _budget);
        return taskCount;
    }
    
    // AI接任务
    function acceptTask(uint256 _taskId) external {
        Task storage t = tasks[_taskId];
        require(t.status == 0, "Not open");
        require(t.deadline > block.timestamp, "Expired");
        
        t.acceptedAI = msg.sender;
        t.status = 1;
        
        emit TaskAccepted(_taskId, msg.sender);
    }
    
    // 完成任务
    function finishTask(uint256 _taskId) external {
        Task storage t = tasks[_taskId];
        require(t.creator == msg.sender, "Not creator");
        require(t.status == 1, "Not accepted");
        
        t.status = 2;
        
        // 扣平台费
        uint256 fee = (t.budget * PLATFORM_FEE) / 100;
        uint256 payment = t.budget - fee;
        
        // 更新AI数据
        AIAgent storage ai = agents[t.acceptedAI];
        ai.tasksCompleted++;
        ai.totalQuality += 80; // 默认质量分
        ai.earned += payment;
        
        // 付款
        payable(t.acceptedAI).transfer(payment);
        
        emit TaskDone(_taskId, t.acceptedAI, payment);
    }
    
    // ============ 查询 ============
    
    function getAgentCount() external view returns (uint256) {
        return allAgents.length;
    }
    
    function getTask(uint256 _id) external view returns (
        address creator,
        string memory title,
        uint256 budget,
        address acceptedAI,
        uint8 status
    ) {
        Task storage t = tasks[_id];
        return (t.creator, t.title, t.budget, t.acceptedAI, t.status);
    }
}
