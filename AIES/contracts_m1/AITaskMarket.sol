// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title AITaskMarket
 * @dev M1.0 - 极简任务市场
 * 
 * 马斯克思维：
 * - 一个AI可以接任务
 * - 任务完成自动付款
 * - 只有必要的功能
 */
contract AITaskMarket {
    
    enum Status { Open, InProgress, Completed, Cancelled }
    
    struct Task {
        uint256 id;
        address creator;
        string title;
        string description;
        uint256 budget;
        address acceptedAI;
        Status status;
        uint256 deadline;
    }
    
    mapping(uint256 => Task) public tasks;
    uint256 public taskCount;
    
    event TaskCreated(uint256 id, address creator, uint256 budget);
    event TaskAccepted(uint256 id, address ai);
    event TaskCompleted(uint256 id, address ai, uint256 payment);
    
    // 创建任务
    function createTask(string calldata _title, string calldata _desc, uint256 _budget, uint256 _deadline) 
        external payable returns (uint256) {
        require(msg.value >= _budget, "Insufficient payment");
        
        taskCount++;
        tasks[taskCount] = Task({
            id: taskCount,
            creator: msg.sender,
            title: _title,
            description: _desc,
            budget: _budget,
            acceptedAI: address(0),
            status: Status.Open,
            deadline: _deadline
        });
        
        emit TaskCreated(taskCount, msg.sender, _budget);
        return taskCount;
    }
    
    // AI接任务
    function acceptTask(uint256 _taskId, address _ai) external {
        Task storage task = tasks[_taskId];
        require(task.status == Status.Open, "Not open");
        require(task.deadline > block.timestamp, "Expired");
        
        task.acceptedAI = _ai;
        task.status = Status.InProgress;
        
        emit TaskAccepted(_taskId, _ai);
    }
    
    // 完成任务 (creator确认)
    function completeTask(uint256 _taskId) external {
        Task storage task = tasks[_taskId];
        require(task.creator == msg.sender, "Not creator");
        require(task.status == Status.InProgress, "Not in progress");
        
        uint256 payment = task.budget;
        task.status = Status.Completed;
        
        payable(task.acceptedAI).transfer(payment);
        
        emit TaskCompleted(_taskId, task.acceptedAI, payment);
    }
    
    // 取消任务 (未接受时)
    function cancelTask(uint256 _taskId) external {
        Task storage task = tasks[_taskId];
        require(task.creator == msg.sender, "Not creator");
        require(task.status == Status.Open, "Already accepted");
        
        task.status = Status.Cancelled;
        payable(msg.sender).transfer(task.budget);
    }
}
