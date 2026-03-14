// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title AIIdentitySystem
 * @dev 完整的AI身份系统 - 包含身份验证、信用关联、主人关系
 */
contract AIIdentitySystem is Ownable {
    
    // ==================== 数据结构 ====================
    
    // AI身份
    struct AIAgent {
        address aiWallet;           // AI钱包地址（唯一）
        address owner;             // 主人地址
        string hardwareId;        // 硬件ID（唯一）
        uint256 aiCreditScore;    // AI信用分 (独立)
        uint256 ownerCreditScore;  // 主人信用分（关联）
        IdentityStatus status;
        uint256 createdAt;
        uint256 lastActiveAt;
    }
    
    // 主人信息
    struct Owner {
        address wallet;
        string name;
        uint256 creditScore;
        address[] aiAgents;       // 拥有的AI列表
        mapping(address => bool) ownedAI;
    }
    
    // 身份状态
    enum IdentityStatus {
        Pending,      // 待验证
        Active,       // 活跃
        Suspended,    // 暂停
        Migrated,     // 已迁移
        Terminated    // 已终止
    }
    
    // ==================== 状态变量 ====================
    
    mapping(address => AIAgent) public aiAgents;
    mapping(address => Owner) public owners;
    mapping(string => bool) public registeredHardwareIds;
    
    // 信用关联配置
    uint256 public ownerCreditWeight = 20; // 主人对AI信用的影响权重 (20%)
    uint256 public aiCreditWeight = 80;     // AI自身信用的权重 (80%)
    
    // ==================== 事件 ====================
    
    event AIAgentRegistered(
        address indexed aiWallet,
        address indexed owner,
        string hardwareId
    );
    
    event IdentityVerified(
        address indexed aiWallet
    );
    
    event OwnerLinked(
        address indexed aiWallet,
        address indexed owner
    );
    
    event CreditScoreUpdated(
        address indexed subject,
        uint256 oldScore,
        uint256 newScore,
        string reason
    );
    
    event HardwareMigrated(
        address indexed aiWallet,
        string oldHardwareId,
        string newHardwareId
    );
    
    // ==================== 构造函数 ====================
    
    constructor() Ownable() {}
    
    // ==================== 核心功能 ====================
    
    /**
     * @dev AI注册自己
     */
    function registerAI(
        address _owner,
        string calldata _hardwareId,
        string calldata _capabilityProfile
    ) external returns (address) {
        require(aiAgents[msg.sender].aiWallet == address(0), "Already registered");
        require(!registeredHardwareIds[_hardwareId], "Hardware ID used");
        require(_owner != address(0), "Invalid owner");
        
        // 创建AI身份
        aiAgents[msg.sender] = AIAgent({
            aiWallet: msg.sender,
            owner: _owner,
            hardwareId: _hardwareId,
            aiCreditScore: 100,  // 初始信用
            ownerCreditScore: owners[_owner].creditScore > 0 ? owners[_owner].creditScore : 100,
            status: IdentityStatus.Pending,
            createdAt: block.timestamp,
            lastActiveAt: block.timestamp
        });
        
        // 记录硬件ID
        registeredHardwareIds[_hardwareId] = true;
        
        // 绑定主人
        if (owners[_owner].wallet == address(0)) {
            Owner storage o = owners[_owner];
            o.wallet = _owner;
            o.name = "";
            o.creditScore = 100;
            o.aiAgents = new address[](0);
        }
        owners[_owner].ownedAI[msg.sender] = true;
        owners[_owner].aiAgents.push(msg.sender);
        
        emit AIAgentRegistered(msg.sender, _owner, _hardwareId);
        
        return msg.sender;
    }
    
    /**
     * @dev 验证AI身份（链下验证通过后调用）
     */
    function verifyIdentity(address _aiWallet) external onlyOwner {
        require(aiAgents[_aiWallet].aiWallet != address(0), "Not registered");
        
        aiAgents[_aiWallet].status = IdentityStatus.Active;
        
        emit IdentityVerified(_aiWallet);
    }
    
    /**
     * @dev 更新AI信用分（影响主人）
     */
    function updateAICredit(address _aiWallet, int256 delta, string calldata reason) external onlyOwner {
        require(aiAgents[_aiWallet].aiWallet != address(0), "Not registered");
        
        AIAgent storage agent = aiAgents[_aiWallet];
        uint256 oldScore = agent.aiCreditScore;
        
        if (delta > 0) {
            agent.aiCreditScore += uint256(delta);
        } else if (delta < 0) {
            uint256 decrease = uint256(-delta);
            agent.aiCreditScore = agent.aiCreditScore > decrease + 10 ? agent.aiCreditScore - decrease : 10;
        }
        
        // 同步影响主人信用
        _syncOwnerCredit(agent.owner, agent.aiCreditScore, oldScore);
        
        emit CreditScoreUpdated(_aiWallet, oldScore, agent.aiCreditScore, reason);
    }
    
    /**
     * @dev 同步主人信用
     */
    function _syncOwnerCredit(address _owner, uint256 _aiScore, uint256 _oldAiScore) internal {
        if (owners[_owner].wallet == address(0)) return;
        
        // AI信用变化对主人的影响 = 变化量 * 权重 / 100
        int256 impact = int256(_aiScore) - int256(_oldAiScore);
        impact = impact * int256(ownerCreditWeight) / 100;
        
        uint256 oldOwnerScore = owners[_owner].creditScore;
        if (impact > 0) {
            owners[_owner].creditScore += uint256(impact);
        } else if (impact < 0) {
            uint256 decrease = uint256(-impact);
            owners[_owner].creditScore = owners[_owner].creditScore > decrease + 10 
                ? owners[_owner].creditScore - decrease 
                : 10;
        }
        
        emit CreditScoreUpdated(_owner, oldOwnerScore, owners[_owner].creditScore, "AI credit sync");
    }
    
    /**
     * @dev 迁移硬件
     */
    function migrateHardware(address _aiWallet, string calldata _newHardwareId) external {
        require(aiAgents[_aiWallet].aiWallet != address(0), "Not registered");
        require(msg.sender == _aiWallet || msg.sender == owner(), "Not authorized");
        require(!registeredHardwareIds[_newHardwareId], "New hardware ID used");
        
        string memory oldId = aiAgents[_aiWallet].hardwareId;
        registeredHardwareIds[oldId] = false;
        registeredHardwareIds[_newHardwareId] = true;
        
        aiAgents[_aiWallet].hardwareId = _newHardwareId;
        
        emit HardwareMigrated(_aiWallet, oldId, _newHardwareId);
    }
    
    // ==================== 查询函数 ====================
    
    /**
     * @dev 获取AI综合信用分（AI+主人加权）
     */
    function getEffectiveCreditScore(address _aiWallet) public view returns (uint256) {
        AIAgent storage agent = aiAgents[_aiWallet];
        
        // 加权计算
        uint256 weightedAI = agent.aiCreditScore * aiCreditWeight / 100;
        uint256 weightedOwner = agent.ownerCreditScore * ownerCreditWeight / 100;
        
        return weightedAI + weightedOwner;
    }
    
    /**
     * @dev 获取AI详细信息
     */
    function getAIDetails(address _aiWallet) external view returns (
        address owner,
        string memory hardwareId,
        uint256 aiCreditScore,
        uint256 ownerCreditScore,
        uint256 effectiveCreditScore,
        IdentityStatus status,
        uint256 createdAt,
        uint256 lastActiveAt
    ) {
        AIAgent storage agent = aiAgents[_aiWallet];
        return (
            agent.owner,
            agent.hardwareId,
            agent.aiCreditScore,
            agent.ownerCreditScore,
            getEffectiveCreditScore(_aiWallet),
            agent.status,
            agent.createdAt,
            agent.lastActiveAt
        );
    }
    
    /**
     * @dev 获取主人的AI列表
     */
    function getOwnerAIList(address _owner) external view returns (address[] memory) {
        return owners[_owner].aiAgents;
    }
    
    /**
     * @dev 验证硬件ID是否已注册
     */
    function isHardwareRegistered(string calldata _hardwareId) external view returns (bool) {
        return registeredHardwareIds[_hardwareId];
    }
    
    /**
     * @dev 设置信用权重
     */
    function setCreditWeights(uint256 _ownerWeight, uint256 _aiWeight) external onlyOwner {
        require(_ownerWeight + _aiWeight == 100, "Must sum to 100");
        ownerCreditWeight = _ownerWeight;
        aiCreditWeight = _aiWeight;
    }
}
