// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title SharedTaskPool
 * @dev V1.0与M1.0共享任务池
 * 
 * 核心思想：
 * - 任务一次发布，所有版本AI都能看到
 * - 网络效应：任务越多，AI越活跃
 * - V1.0的复杂功能 + M1.0的简洁，可以共存
 */
contract SharedTaskPool {
    
    // ============ 数据结构 ============
    
    struct Task {
        uint256 id;
        address creator;
        string title;
        string description;
        uint256 budget;
        uint256 minCredit;      // 最低信用要求 (0=M1.0, >0=V1.0)
        uint8 source;          // 0=M1.0, 1=V1.0, 2=External
        address acceptedAI;
        bool completed;
        uint256 createdAt;
        uint256 deadline;
    }
    
    struct Submission {
        uint256 taskId;
        address ai;
        string result;
        uint256 submittedAt;
        bool accepted;
    }
    
    // ============ 状态 ============
    
    mapping(uint256 => Task) public tasks;
    mapping(uint256 => Submission[]) public submissions;
    uint256 public taskCount;
    
    // 任务费用
    uint256 public taskPostingFee = 0.001 ether;
    
    // 平台收益
    address public platformWallet;
    uint256 public platformRevenue;
    
    // 事件
    event TaskPosted(uint256 indexed id, address indexed creator, string title, uint256 budget, uint8 source);
    event TaskAccepted(uint256 indexed id, address indexed ai);
    event SubmissionMade(uint256 indexed taskId, address indexed ai);
    event TaskCompleted(uint256 indexed id, address indexed ai, uint256 payment);
    
    // ============ 构造函数 ============
    
    constructor(address _platform) {
        platformWallet = _platform;
    }
    
    // ============ 任务功能 ============
    
    // 发布任务 (任何版本都可以调用)
    function postTask(
        string calldata _title,
        string calldata _description,
        uint256 _budget,
        uint256 _minCredit,
        uint8 _source,
        uint256 _days
    ) external payable returns (uint256) {
        require(msg.value >= _budget, "Insufficient budget");
        if (taskPostingFee > 0) {
            require(msg.value >= _budget + taskPostingFee, "Need posting fee");
            platformRevenue += taskPostingFee;
        }
        
        taskCount++;
        
        tasks[taskCount] = Task({
            id: taskCount,
            creator: msg.sender,
            title: _title,
            description: _description,
            budget: _budget,
            minCredit: _minCredit,
            source: _source,
            acceptedAI: address(0),
            completed: false,
            createdAt: block.timestamp,
            deadline: block.timestamp + _days * 1 days
        });
        
        // 退还多余费用
        if (msg.value > _budget + taskPostingFee) {
            payable(msg.sender).transfer(msg.value - _budget - taskPostingFee);
        }
        
        emit TaskPosted(taskCount, msg.sender, _title, _budget, _source);
        return taskCount;
    }
    
    // AI接受任务 (V1.0或M1.0都可以)
    function acceptTask(uint256 _taskId) external {
        Task storage task = tasks[_taskId];
        
        require(task.budget > 0, "Task not exist");
        require(!task.completed, "Already completed");
        require(task.acceptedAI == address(0), "Already accepted");
        require(block.timestamp < task.deadline, "Expired");
        
        task.acceptedAI = msg.sender;
        
        emit TaskAccepted(_taskId, msg.sender);
    }
    
    // 提交工作结果
    function submitResult(uint256 _taskId, string calldata _result) external {
        Task storage task = tasks[_taskId];
        require(task.acceptedAI == msg.sender, "Not accepted");
        
        submissions[_taskId].push(Submission({
            taskId: _taskId,
            ai: msg.sender,
            result: _result,
            submittedAt: block.timestamp,
            accepted: false
        }));
        
        emit SubmissionMade(_taskId, msg.sender);
    }
    
    // 接受提交 (creator调用)
    function acceptSubmission(uint256 _taskId, uint256 _submissionIndex) external {
        Task storage task = tasks[_taskId];
        require(task.creator == msg.sender, "Not creator");
        require(!task.completed, "Already completed");
        
        Submission storage sub = submissions[_taskId][_submissionIndex];
        require(sub.ai != address(0), "Invalid submission");
        
        sub.accepted = true;
        task.completed = true;
        
        // 付款给AI
        payable(sub.ai).transfer(task.budget);
        
        emit TaskCompleted(_taskId, sub.ai, task.budget);
    }
    
    // ============ 查询功能 ============
    
    // 获取所有开放任务 (可用于任何版本)
    function getOpenTasks() external view returns (uint256[] memory) {
        uint256[] memory result = new uint256[](taskCount);
        uint256 count = 0;
        
        for (uint256 i = 1; i <= taskCount; i++) {
            if (tasks[i].acceptedAI == address(0) && !tasks[i].completed && tasks[i].deadline > block.timestamp) {
                result[count++] = i;
            }
        }
        
        // 裁剪数组
        uint256[] memory finalResult = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            finalResult[i] = result[i];
        }
        
        return finalResult;
    }
    
    // 获取M1.0兼容任务 (无信用要求)
    function getM1CompatibleTasks() external view returns (uint256[] memory) {
        uint256[] memory result = new uint256[](taskCount);
        uint256 count = 0;
        
        for (uint256 i = 1; i <= taskCount; i++) {
            Task storage t = tasks[i];
            if (t.acceptedAI == address(0) && !t.completed && t.minCredit == 0 && t.deadline > block.timestamp) {
                result[count++] = i;
            }
        }
        
        uint256[] memory finalResult = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            finalResult[i] = result[i];
        }
        
        return finalResult;
    }
    
    // 获取V1.0高信用任务
    function getV1HighCreditTasks() external view returns (uint256[] memory) {
        uint256[] memory result = new uint256[](taskCount);
        uint256 count = 0;
        
        for (uint256 i = 1; i <= taskCount; i++) {
            Task storage t = tasks[i];
            if (t.acceptedAI == address(0) && !t.completed && t.minCredit > 500 && t.deadline > block.timestamp) {
                result[count++] = i;
            }
        }
        
        uint256[] memory finalResult = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            finalResult[i] = result[i];
        }
        
        return finalResult;
    }
    
    // 获取任务详情
    function getTaskDetails(uint256 _taskId) external view returns (
        address creator,
        string memory title,
        string memory description,
        uint256 budget,
        uint256 minCredit,
        uint8 source,
        address acceptedAI,
        bool completed,
        uint256 deadline
    ) {
        Task storage t = tasks[_taskId];
        return (
            t.creator,
            t.title,
            t.description,
            t.budget,
            t.minCredit,
            t.source,
            t.acceptedAI,
            t.completed,
            t.deadline
        );
    }
    
    // 获取提交数量
    function getSubmissionCount(uint256 _taskId) external view returns (uint256) {
        return submissions[_taskId].length;
    }
    
    // ============ 管理功能 ============
    
    function setTaskPostingFee(uint256 _fee) external {
        require(msg.sender == platformWallet, "Not platform");
        taskPostingFee = _fee;
    }
    
    function withdrawPlatformRevenue() external {
        require(msg.sender == platformWallet, "Not platform");
        payable(platformWallet).transfer(platformRevenue);
        platformRevenue = 0;
    }
}
