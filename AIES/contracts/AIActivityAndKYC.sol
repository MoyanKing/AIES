// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title AIActivityAndKYC
 * @dev AI活跃度与KYC合约 - 跟踪AI活动和处理身份验证
 */
contract AIActivityAndKYC is Ownable {
    
    enum KYCLevel { None, Basic, Verified, Premium }
    enum ActivityType { TaskCompleted, SwarmJoined, ProposalVoted, LoanRepaid, DisputeResolved }
    
    struct ActivityRecord {
        uint256 timestamp;
        ActivityType activityType;
        uint256 value; // 可以是任务ID、投票权重等
    }
    
    struct AIProfile {
        address aiWallet;
        string hardwareId;
        KYCLevel kycLevel;
        uint256 totalTasksCompleted;
        uint256 totalSwarmParticipated;
        uint256 totalProposalsVoted;
        uint256 streakDays;
        uint256 lastActiveDate;
        uint256 totalActiveDays;
        ActivityRecord[] activities;
        mapping(bytes32 => bool) verifiedClaims;
    }
    
    mapping(address => AIProfile) public aiProfiles;
    mapping(string => bool) public usedHardwareIds;
    
    // 活跃度奖励配置
    uint256 public dailyActiveThreshold = 1; // 每天至少1个活动
    uint256 public streakBonusPercent = 5;   // 连续活跃奖励5%
    uint256 public maxStreakBonus = 30;       // 最高连续奖励30天
    
    // KYC验证者
    mapping(address => bool) public kycVerifiers;
    address[] public verifierList;
    
    // 事件
    event ActivityRecorded(address indexed ai, ActivityType activityType, uint256 value);
    event KYCUpdated(address indexed ai, KYCLevel oldLevel, KYCLevel newLevel);
    event ClaimVerified(address indexed ai, bytes32 claimHash);
    event StreakUpdated(address indexed ai, uint256 newStreak);
    event VerifierAdded(address indexed verifier);
    event VerifierRemoved(address indexed verifier);
    
    constructor() Ownable() {
        kycVerifiers[msg.sender] = true;
        verifierList.push(msg.sender);
    }
    
    // 记录活动
    function recordActivity(address _ai, ActivityType _activityType, uint256 _value) external {
        require(msg.sender == owner() || kycVerifiers[msg.sender], "Not authorized");
        
        AIProfile storage profile = aiProfiles[_ai];
        require(profile.aiWallet != address(0), "Profile not exist");
        
        // 检查是否是连续活跃
        uint256 today = block.timestamp / 86400;
        uint256 lastActive = profile.lastActiveDate / 86400;
        
        if (today > lastActive) {
            if (today - lastActive == 1) {
                // 连续活跃
                profile.streakDays++;
            } else {
                // 断开连续
                profile.streakDays = 1;
            }
            profile.totalActiveDays++;
            profile.lastActiveDate = block.timestamp;
        }
        
        // 更新统计
        if (_activityType == ActivityType.TaskCompleted) {
            profile.totalTasksCompleted++;
        } else if (_activityType == ActivityType.SwarmJoined) {
            profile.totalSwarmParticipated++;
        } else if (_activityType == ActivityType.ProposalVoted) {
            profile.totalProposalsVoted++;
        }
        
        // 记录活动
        profile.activities.push(ActivityRecord({
            timestamp: block.timestamp,
            activityType: _activityType,
            value: _value
        }));
        
        emit ActivityRecorded(_ai, _activityType, _value);
        
        if (profile.streakDays > 1) {
            emit StreakUpdated(_ai, profile.streakDays);
        }
    }
    
    // 创建AI档案
    function createProfile(address _ai, string calldata _hardwareId) external {
        require(aiProfiles[_ai].aiWallet == address(0), "Profile exists");
        require(!usedHardwareIds[_hardwareId], "Hardware ID used");
        
        AIProfile storage profile = aiProfiles[_ai];
        profile.aiWallet = _ai;
        profile.hardwareId = _hardwareId;
        profile.kycLevel = KYCLevel.None;
        profile.totalTasksCompleted = 0;
        profile.totalSwarmParticipated = 0;
        profile.totalProposalsVoted = 0;
        profile.streakDays = 0;
        profile.lastActiveDate = 0;
        profile.totalActiveDays = 0;
        
        usedHardwareIds[_hardwareId] = true;
    }
    
    // 更新KYC等级
    function updateKYC(address _ai, KYCLevel _level) external {
        require(kycVerifiers[msg.sender] || msg.sender == owner(), "Not verifier");
        
        AIProfile storage profile = aiProfiles[_ai];
        require(profile.aiWallet != address(0), "Profile not exist");
        
        KYCLevel oldLevel = profile.kycLevel;
        profile.kycLevel = _level;
        
        emit KYCUpdated(_ai, oldLevel, _level);
    }
    
    // 添加声明验证
    function addClaim(address _ai, bytes32 _claimHash) external {
        require(msg.sender == owner() || kycVerifiers[msg.sender], "Not authorized");
        
        AIProfile storage profile = aiProfiles[_ai];
        profile.verifiedClaims[_claimHash] = true;
        
        emit ClaimVerified(_ai, _claimHash);
    }
    
    // 验证声明
    function verifyClaim(address _ai, bytes32 _claimHash) external view returns (bool) {
        return aiProfiles[_ai].verifiedClaims[_claimHash];
    }
    
    // 添加KYC验证者
    function addVerifier(address _verifier) external onlyOwner {
        require(!kycVerifiers[_verifier], "Already verifier");
        
        kycVerifiers[_verifier] = true;
        verifierList.push(_verifier);
        
        emit VerifierAdded(_verifier);
    }
    
    // 移除KYC验证者
    function removeVerifier(address _verifier) external onlyOwner {
        require(kycVerifiers[_verifier], "Not verifier");
        
        kycVerifiers[_verifier] = false;
        
        emit VerifierRemoved(_verifier);
    }
    
    // 获取活跃度奖励
    function getActivityBonus(address _ai) public view returns (uint256) {
        AIProfile storage profile = aiProfiles[_ai];
        
        if (profile.streakDays == 0) return 0;
        
        uint256 streakBonus = profile.streakDays > maxStreakBonus ? maxStreakBonus : profile.streakDays;
        return streakBonusPercent * streakBonus;
    }
    
    // 获取档案详情
    function getProfileDetails(address _ai) external view returns (
        address wallet,
        string memory hardwareId,
        KYCLevel kycLevel,
        uint256 totalTasks,
        uint256 totalSwarm,
        uint256 totalVotes,
        uint256 streakDays,
        uint256 totalActiveDays,
        uint256 activityCount
    ) {
        AIProfile storage profile = aiProfiles[_ai];
        return (
            profile.aiWallet,
            profile.hardwareId,
            profile.kycLevel,
            profile.totalTasksCompleted,
            profile.totalSwarmParticipated,
            profile.totalProposalsVoted,
            profile.streakDays,
            profile.totalActiveDays,
            profile.activities.length
        );
    }
    
    // 获取特定活动
    function getActivity(address _ai, uint256 _index) external view returns (
        uint256 timestamp,
        ActivityType activityType,
        uint256 value
    ) {
        AIProfile storage profile = aiProfiles[_ai];
        require(_index < profile.activities.length, "Invalid index");
        
        ActivityRecord storage record = profile.activities[_index];
        return (record.timestamp, record.activityType, record.value);
    }
    
    // 设置活跃度配置
    function setActivityConfig(uint256 _dailyThreshold, uint256 _streakBonus, uint256 _maxStreak) external onlyOwner {
        dailyActiveThreshold = _dailyThreshold;
        streakBonusPercent = _streakBonus;
        maxStreakBonus = _maxStreak;
    }
}
