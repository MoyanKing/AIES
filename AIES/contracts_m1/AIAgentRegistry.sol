// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title AIAgentRegistry
 * @dev M1.0 - AI智能体注册与简单信用
 * 
 * 马斯克思维：
 * - 极简：只有一个功能：注册AI
 * - 信用 = 完成任务数 × 质量
 * - 不需要复杂的权重系统
 */
contract AIAgentRegistry {
    
    struct AIAgent {
        address wallet;
        address owner;
        string name;
        uint256 tasksCompleted;
        uint256 totalQualityScore;
        uint256 earned; // 总收入 (ETH)
        uint256 ownerShare; // 主人分成比例 (5-95)
        uint256 createdAt;
    }
    
    mapping(address => AIAgent) public agents;
    address[] public agentList;
    
    event AIRegistered(address indexed ai, address indexed owner, string name);
    event TaskCompleted(address indexed ai, uint256 quality, uint256 reward);
    event OwnerShareUpdated(address indexed ai, uint256 newShare);
    
    // 主人设置分成比例
    function setOwnerShare(uint256 _sharePercent) external {
        require(_sharePercent >= 5 && _sharePercent <= 95, "5-95");
        AIAgent storage agent = agents[msg.sender];
        require(agent.wallet == msg.sender, "Not registered");
        agent.ownerShare = _sharePercent;
        emit OwnerShareUpdated(msg.sender, _sharePercent);
    }
    
    // 注册AI
    function register(address _owner, string calldata _name) external {
        require(agents[msg.sender].wallet == address(0), "Already registered");
        
        agents[msg.sender] = AIAgent({
            wallet: msg.sender,
            owner: _owner,
            name: _name,
            tasksCompleted: 0,
            totalQualityScore: 0,
            earned: 0,
            ownerShare: 10, // 默认10%
            createdAt: block.timestamp
        });
        
        agentList.push(msg.sender);
        emit AIRegistered(msg.sender, _owner, _name);
    }
    
    // 完成任务获得收入 (由任务合约调用)
    function completeTask(address _ai, uint256 _quality, uint256 _reward) external {
        AIAgent storage agent = agents[_ai];
        require(agent.wallet == _ai, "Not registered");
        
        agent.tasksCompleted++;
        agent.totalQualityScore += _quality;
        agent.earned += _reward;
    }
    
    // 获取AI信用分 (简单计算)
    function getCreditScore(address _ai) public view returns (uint256) {
        AIAgent storage agent = agents[_ai];
        if (agent.tasksCompleted == 0) return 100; // 默认
        return 100 + (agent.tasksCompleted * 10) + (agent.totalQualityScore / agent.tasksCompleted);
    }
    
    // 获取AI详情
    function getAgentInfo(address _ai) external view returns (
        address owner,
        string memory name,
        uint256 tasksCompleted,
        uint256 creditScore,
        uint256 earned,
        uint256 ownerShare
    ) {
        AIAgent storage agent = agents[_ai];
        return (
            agent.owner,
            agent.name,
            agent.tasksCompleted,
            getCreditScore(_ai),
            agent.earned,
            agent.ownerShare
        );
    }
}
