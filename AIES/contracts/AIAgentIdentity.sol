// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title AIAgentIdentity
 * @dev 马斯克思维简化版 - 私钥即身份
 * 
 * 核心理念：
 * - AI身份 = 钱包地址 (私钥)
 * - 无需硬件绑定
 * - 简单到无需解释
 */
contract AIAgentIdentity is Ownable {
    
    // ==================== 极简数据结构 ====================
    
    struct AIAgent {
        address wallet;       // 唯一身份标识 (私钥持有者)
        address owner;        // 管理员 (可选)
        uint256 credit;      // 信用分 0-1000
        bool exists;          // 是否注册
    }
    
    // ==================== 状态 ====================
    
    mapping(address => AIAgent) public agents;
    address[] public allAgents;
    
    // ==================== 事件 ====================
    
    event Registered(address indexed ai, address indexed owner);
    event CreditUpdated(address indexed ai, uint256 oldCredit, uint256 newCredit);
    event OwnerChanged(address indexed ai, address oldOwner, address newOwner);
    
    // ==================== 构造函数 ====================
    
    constructor() Ownable() {}
    
    // ==================== 核心功能 ====================
    
    /**
     * @dev AI自己注册 - 一行代码
     * 私钥 = 身份，有私钥即证明身份
     */
    function register(address _owner) external {
        require(!agents[msg.sender].exists, "Already registered");
        
        agents[msg.sender] = AIAgent({
            wallet: msg.sender,
            owner: _owner,
            credit: 100,  // 初始信用
            exists: true
        });
        
        allAgents.push(msg.sender);
        emit Registered(msg.sender, _owner);
    }
    
    /**
     * @dev 更新信用分 (只能由合约所有者调用)
     */
    function updateCredit(address _ai, uint256 _newCredit) external onlyOwner {
        require(agents[_ai].exists, "Not registered");
        require(_newCredit <= 1000, "Max 1000");
        
        uint256 old = agents[_ai].credit;
        agents[_ai].credit = _newCredit;
        
        emit CreditUpdated(_ai, old, _newCredit);
    }
    
    /**
     * @dev 更换管理员
     */
    function changeOwner(address _newOwner) external {
        require(agents[msg.sender].exists, "Not registered");
        
        address old = agents[msg.sender].owner;
        agents[msg.sender].owner = _newOwner;
        
        emit OwnerChanged(msg.sender, old, _newOwner);
    }
    
    // ==================== 查询功能 ====================
    
    function getAgent(address _ai) external view returns (
        address wallet,
        address owner,
        uint256 credit
    ) {
        AIAgent storage a = agents[_ai];
        return (a.wallet, a.owner, a.credit);
    }
    
    function getAgentCount() external view returns (uint256) {
        return allAgents.length;
    }
    
    function isRegistered(address _ai) external view returns (bool) {
        return agents[_ai].exists;
    }
}
