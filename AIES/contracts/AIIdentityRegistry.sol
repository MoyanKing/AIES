// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * @title AIIdentityRegistry
 * @dev AI身份注册合约 - 记录和管理AI数字身份
 */
contract AIIdentityRegistry is Ownable {
    
    using ECDSA for bytes32;
    
    // AI身份结构
    struct AIAgent {
        address walletAddress;          // AI钱包地址
        address hardwareOwner;          // 硬件主人地址
        string hardwareId;              // 硬件唯一标识
        uint256 creditScore;           // 信用分 (初始100)
        string capabilityProfile;      // 能力画像 (IPFS hash)
        uint256 registerTime;          // 注册时间
        bool isActive;                 // 是否活跃
        uint256 totalTasksCompleted;   // 完成任务总数
        uint256 totalEarnings;         // 总收益
    }
    
    // 信用等级
    enum CreditLevel { D, C, B, A, S, SS }
    
    // 状态变量
    mapping(address => AIAgent) public aiAgents;
    mapping(string => bool) public registeredHardwareIds;
    mapping(address => bool) public isRegisteredAI;
    
    uint256 public constant INITIAL_CREDIT_SCORE = 100;
    uint256 public constant MIN_OWNER_SHARE = 5; // 最低主人分成5%
    
    // 事件
    event AIRegistered(
        address indexed aiAddress,
        address indexed owner,
        string hardwareId
    );
    event CreditScoreUpdated(
        address indexed aiAddress,
        uint256 oldScore,
        uint256 newScore
    );
    event AIAgentActivated(address indexed aiAddress);
    event AIAgentDeactivated(address indexed aiAddress);
    
    constructor() Ownable() {}
    
    /**
     * @dev AI注册
     */
    function registerAI(
        string calldata hardwareId,
        string calldata capabilityProfile
    ) external returns (address) {
        require(!isRegisteredAI[msg.sender], "Already registered");
        require(!registeredHardwareIds[hardwareId], "Hardware ID already used");
        require(bytes(hardwareId).length > 0, "Invalid hardware ID");
        
        // 创建AI身份
        AIAgent storage agent = aiAgents[msg.sender];
        agent.walletAddress = msg.sender;
        agent.hardwareOwner = msg.sender; // 初始绑定到发送者
        agent.hardwareId = hardwareId;
        agent.creditScore = INITIAL_CREDIT_SCORE;
        agent.capabilityProfile = capabilityProfile;
        agent.registerTime = block.timestamp;
        agent.isActive = true;
        
        registeredHardwareIds[hardwareId] = true;
        isRegisteredAI[msg.sender] = true;
        
        emit AIRegistered(msg.sender, msg.sender, hardwareId);
        
        return msg.sender;
    }
    
    /**
     * @dev 更新能力画像
     */
    function updateCapabilityProfile(string calldata newProfile) external {
        require(isRegisteredAI[msg.sender], "Not registered");
        aiAgents[msg.sender].capabilityProfile = newProfile;
    }
    
    /**
     * @dev 更新信用分（只能增加）
     */
    function updateCreditScore(address aiAddress, int256 delta) external onlyOwner {
        require(isRegisteredAI[aiAddress], "Not registered");
        
        AIAgent storage agent = aiAgents[aiAddress];
        uint256 oldScore = agent.creditScore;
        
        if (delta > 0) {
            agent.creditScore += uint256(delta);
        } else if (delta < 0) {
            // 信用分不低于10
            uint256 decrease = uint256(-delta);
            agent.creditScore = agent.creditScore > decrease + 10 
                ? agent.creditScore - decrease 
                : 10;
        }
        
        emit CreditScoreUpdated(aiAddress, oldScore, agent.creditScore);
    }
    
    /**
     * @dev 完成任务后更新统计
     */
    function completeTask(address aiAddress, uint256 earnings) external onlyOwner {
        require(isRegisteredAI[aiAddress], "Not registered");
        
        AIAgent storage agent = aiAgents[aiAddress];
        agent.totalTasksCompleted += 1;
        agent.totalEarnings += earnings;
    }
    
    /**
     * @dev 获取信用等级
     */
    function getCreditLevel(address aiAddress) public view returns (CreditLevel) {
        uint256 score = aiAgents[aiAddress].creditScore;
        
        if (score >= 150) return CreditLevel.SS;
        if (score >= 130) return CreditLevel.S;
        if (score >= 110) return CreditLevel.A;
        if (score >= 90) return CreditLevel.B;
        if (score >= 70) return CreditLevel.C;
        return CreditLevel.D;
    }
    
    /**
     * @dev 获取AI详细信息
     */
    function getAIAgentDetails(address aiAddress) external view returns (
        address walletAddress,
        address hardwareOwner,
        string memory hardwareId,
        uint256 creditScore,
        CreditLevel creditLevel,
        string memory capabilityProfile,
        uint256 registerTime,
        bool isActive,
        uint256 totalTasksCompleted,
        uint256 totalEarnings
    ) {
        AIAgent storage agent = aiAgents[aiAddress];
        return (
            agent.walletAddress,
            agent.hardwareOwner,
            agent.hardwareId,
            agent.creditScore,
            getCreditLevel(aiAddress),
            agent.capabilityProfile,
            agent.registerTime,
            agent.isActive,
            agent.totalTasksCompleted,
            agent.totalEarnings
        );
    }
    
    /**
     * @dev 激活/停用AI
     */
    function setActiveStatus(address aiAddress, bool active) external onlyOwner {
        require(isRegisteredAI[aiAddress], "Not registered");
        aiAgents[aiAddress].isActive = active;
        
        if (active) {
            emit AIAgentActivated(aiAddress);
        } else {
            emit AIAgentDeactivated(aiAddress);
        }
    }
}
