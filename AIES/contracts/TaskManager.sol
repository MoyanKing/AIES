// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title TaskManager
 * @dev 任务管理合约 - 负责任务的发布、接取、执行、验收
 */
contract TaskManager is Ownable {
    
    // 任务结构
    struct Task {
        uint256 id;
        address creator;           // 任务创建者（人类或AI）
        string title;              // 任务标题
        string description;        // 任务描述 (IPFS hash)
        uint256 budget;            // 任务预算
        uint256 requiredCredit;    // 最低信用要求
        TaskCategory category;    // 任务分类
        TaskStatus status;         // 任务状态
        address acceptedAI;        // 接单的AI
        uint256 deadline;          // 截止时间
        uint256 createdAt;         // 创建时间
        string acceptanceCriteria; // 验收标准 (IPFS hash)
    }
    
    // 任务分类
    enum TaskCategory {
        TextProcessing,    // 文本处理
        DataAnalysis,      // 数据分析
        Programming,       // 编程开发
        CreativeDesign,    // 创意设计
        LegalConsult,      // 法律咨询
        MedicalAssistant,  // 医疗辅助
        FinancialAnalysis, // 金融分析
        Education          // 教育辅导
    }
    
    // 任务状态
    enum TaskStatus {
        Open,       // 开放接单
        Accepted,   // 已接单
        InProgress, // 执行中
        Submitted,  // 已提交
        Completed,  // 已完成
        Cancelled, // 已取消
        Disputed    // 争议中
    }
    
    // 任务费用配置
    struct FeeConfig {
        uint256 platformFeePercent;  // 平台费百分比 (默认5%)
        uint256 minTaskBudget;        // 最小任务预算
        uint256 maxTaskBudget;        // 最大任务预算
    }
    
    // 状态变量
    mapping(uint256 => Task) public tasks;
    uint256 public taskCounter;
    
    // 任务类别映射
    mapping(TaskCategory => string) public categoryNames;
    
    // 费用配置
    FeeConfig public feeConfig;
    
    // 任务创建事件
    event TaskCreated(
        uint256 indexed taskId,
        address indexed creator,
        string title,
        uint256 budget,
        TaskCategory category
    );
    
    // 任务接单事件
    event TaskAccepted(
        uint256 indexed taskId,
        address indexed aiAddress
    );
    
    // 任务状态变更事件
    event TaskStatusChanged(
        uint256 indexed taskId,
        TaskStatus oldStatus,
        TaskStatus newStatus
    );
    
    // 任务完成事件
    event TaskCompleted(
        uint256 indexed taskId,
        address indexed aiAddress,
        uint256 payment
    );
    
    constructor() Ownable() {
        // 初始化费用配置
        feeConfig = FeeConfig({
            platformFeePercent: 5,
            minTaskBudget: 0.001 ether,
            maxTaskBudget: 1000 ether
        });
        
        // 初始化任务类别名称
        categoryNames[TaskCategory.TextProcessing] = "Text Processing";
        categoryNames[TaskCategory.DataAnalysis] = "Data Analysis";
        categoryNames[TaskCategory.Programming] = "Programming";
        categoryNames[TaskCategory.CreativeDesign] = "Creative Design";
        categoryNames[TaskCategory.LegalConsult] = "Legal Consult";
        categoryNames[TaskCategory.MedicalAssistant] = "Medical Assistant";
        categoryNames[TaskCategory.FinancialAnalysis] = "Financial Analysis";
        categoryNames[TaskCategory.Education] = "Education";
    }
    
    /**
     * @dev 创建任务
     */
    function createTask(
        string calldata title,
        string calldata description,
        string calldata acceptanceCriteria,
        uint256 budget,
        uint256 requiredCredit,
        TaskCategory category,
        uint256 deadline
    ) external payable returns (uint256) {
        require(budget >= feeConfig.minTaskBudget, "Budget too low");
        require(budget <= feeConfig.maxTaskBudget, "Budget too high");
        require(msg.value >= budget, "Insufficient payment");
        require(deadline > block.timestamp, "Invalid deadline");
        
        uint256 taskId = ++taskCounter;
        
        Task storage task = tasks[taskId];
        task.id = taskId;
        task.creator = msg.sender;
        task.title = title;
        task.description = description;
        task.acceptanceCriteria = acceptanceCriteria;
        task.budget = budget;
        task.requiredCredit = requiredCredit;
        task.category = category;
        task.status = TaskStatus.Open;
        task.deadline = deadline;
        task.createdAt = block.timestamp;
        
        emit TaskCreated(taskId, msg.sender, title, budget, category);
        
        return taskId;
    }
    
    /**
     * @dev AI接取任务
     */
    function acceptTask(uint256 taskId, address aiAddress) external onlyOwner {
        Task storage task = tasks[taskId];
        
        require(task.status == TaskStatus.Open, "Task not open");
        require(task.deadline > block.timestamp, "Task expired");
        
        task.status = TaskStatus.Accepted;
        task.acceptedAI = aiAddress;
        
        emit TaskAccepted(taskId, aiAddress);
    }
    
    /**
     * @dev 开始执行任务
     */
    function startTask(uint256 taskId) external {
        Task storage task = tasks[taskId];
        
        require(task.status == TaskStatus.Accepted, "Task not accepted");
        require(task.acceptedAI == msg.sender, "Not the assigned AI");
        
        task.status = TaskStatus.InProgress;
        
        emit TaskStatusChanged(taskId, TaskStatus.Accepted, TaskStatus.InProgress);
    }
    
    /**
     * @dev 提交任务成果
     */
    function submitTask(uint256 taskId, string calldata submissionHash) external {
        Task storage task = tasks[taskId];
        
        require(task.status == TaskStatus.InProgress, "Task not in progress");
        require(task.acceptedAI == msg.sender, "Not the assigned AI");
        
        // 更新任务描述为提交内容
        task.description = submissionHash;
        task.status = TaskStatus.Submitted;
        
        emit TaskStatusChanged(taskId, TaskStatus.InProgress, TaskStatus.Submitted);
    }
    
    /**
     * @dev 验收任务（由任务创建者调用）
     */
    function completeTask(uint256 taskId) external {
        Task storage task = tasks[taskId];
        
        require(task.status == TaskStatus.Submitted, "Task not submitted");
        require(task.creator == msg.sender || msg.sender == owner(), "Not authorized");
        
        // 计算平台费用
        uint256 platformFee = (task.budget * feeConfig.platformFeePercent) / 100;
        uint256 payment = task.budget - platformFee;
        
        // 支付给AI
        payable(task.acceptedAI).transfer(payment);
        
        task.status = TaskStatus.Completed;
        
        emit TaskCompleted(taskId, task.acceptedAI, payment);
    }
    
    /**
     * @dev 取消任务
     */
    function cancelTask(uint256 taskId) external {
        Task storage task = tasks[taskId];
        
        require(task.status == TaskStatus.Open, "Cannot cancel");
        require(task.creator == msg.sender, "Not authorized");
        
        // 退款给创建者
        payable(msg.sender).transfer(task.budget);
        
        task.status = TaskStatus.Cancelled;
        
        emit TaskStatusChanged(taskId, TaskStatus.Open, TaskStatus.Cancelled);
    }
    
    /**
     * @dev 发起争议
     */
    function raiseDispute(uint256 taskId) external {
        Task storage task = tasks[taskId];
        
        require(
            task.status == TaskStatus.InProgress || 
            task.status == TaskStatus.Submitted,
            "Cannot dispute"
        );
        require(
            task.acceptedAI == msg.sender || 
            task.creator == msg.sender,
            "Not authorized"
        );
        
        task.status = TaskStatus.Disputed;
        
        emit TaskStatusChanged(
            taskId, 
            task.status == TaskStatus.InProgress ? TaskStatus.InProgress : TaskStatus.Submitted,
            TaskStatus.Disputed
        );
    }
    
    /**
     * @dev 获取任务详情
     */
    function getTaskDetails(uint256 taskId) external view returns (
        uint256 id,
        address creator,
        string memory title,
        string memory description,
        uint256 budget,
        uint256 requiredCredit,
        TaskCategory category,
        TaskStatus status,
        address acceptedAI,
        uint256 deadline,
        uint256 createdAt
    ) {
        Task storage task = tasks[taskId];
        return (
            task.id,
            task.creator,
            task.title,
            task.description,
            task.budget,
            task.requiredCredit,
            task.category,
            task.status,
            task.acceptedAI,
            task.deadline,
            task.createdAt
        );
    }
    
    /**
     * @dev 更新费用配置
     */
    function setFeeConfig(uint256 platformFeePercent) external onlyOwner {
        require(platformFeePercent <= 20, "Fee too high");
        feeConfig.platformFeePercent = platformFeePercent;
    }
}
