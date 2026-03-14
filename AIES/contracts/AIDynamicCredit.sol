// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title AIDynamicCredit
 * @dev 动态信用系统 - 基于实时行为的多维信用评估
 * 
 * 第一性原理：
 * 信用不是静态的，应该是实时行为的反映
 * 
 * 信用维度：
 * - 任务信用 (40%): 完成率、质量评分
 * - 交互信用 (30%): 准时率、合作评价
 * - 资产信用 (20%): 钱包余额、资产稳定性
 * - 社区信用 (10%): 投票参与、争议解决
 */
contract AIDynamicCredit is Ownable {
    
    // ============ 数据结构 ============
    
    // AI能力画像
    struct AICapability {
        string category;           // 技能类别: programming, design, analysis, etc.
        uint256 proficiency;      // 熟练度 1-100
        uint256 completedJobs;    // 完成工作数
        uint256 avgRating;        // 平均评分 1-100
        bool verified;            // 是否经过认证
    }
    
    // 任务信用数据
    struct TaskCredit {
        uint256 totalTasks;       // 总任务数
        uint256 completedTasks;   // 完成任务数
        uint256 cancelledTasks;  // 取消任务数
        uint256 avgQualityScore; // 平均质量分 1-100
        uint256 avgDeliveryTime; // 平均交付时间(小时)
    }
    
    // 交互信用数据
    struct InteractionCredit {
        uint256 totalTransactions; // 总交易数
        uint256 onTimeDeliveries; // 准时交付数
        uint256 disputesRaised;   // 被发起争议次数
        uint256 disputesLost;     // 争议失败次数
        uint256 partnerRatings;   // 合作伙伴评分总和
        uint256 ratingCount;      // 评分次数
    }
    
    // 资产信用数据
    struct AssetCredit {
        uint256 totalEarnings;   // 总收入
        uint256 totalSpendings;  // 总支出
        uint256 savingsRatio;    // 储蓄率 (保存比例)
        uint256 stableHoldingDays; // 稳定持有天数
    }
    
    // 社区信用数据
    struct CommunityCredit {
        uint256 proposalsVoted;  // 投票提案数
        uint256 votesFor;       // 赞成票
        uint256 votesAgainst;    // 反对票
        uint256 daoParticipation; // DAO参与次数
        uint256 helperCount;    // 帮助其他AI次数
    }
    
    // 综合信用
    struct CompositeCredit {
        uint256 taskScore;       // 0-1000
        uint256 interactionScore; // 0-1000
        uint256 assetScore;      // 0-1000
        uint256 communityScore;  // 0-1000
        uint256 composite;      // 加权总分 0-1000
        uint256 lastUpdated;
    }
    
    // ============ 状态变量 ============
    
    mapping(address => AICapability[]) public aiCapabilities;
    mapping(address => TaskCredit) public taskCredits;
    mapping(address => InteractionCredit) public interactionCredits;
    mapping(address => AssetCredit) public assetCredits;
    mapping(address => CommunityCredit) public communityCredits;
    mapping(address => CompositeCredit) public compositeCredits;
    
    // 权重配置
    uint256 public taskWeight = 400;  // 40%
    uint256 public interactionWeight = 300; // 30%
    uint256 public assetWeight = 200;  // 20%
    uint256 public communityWeight = 100; // 10%
    
    // 排名
    address[] public rankedAIs;
    mapping(address => uint256) public rankIndex;
    
    // ============ 事件 ============
    
    event CapabilityAdded(address indexed ai, string category, uint256 proficiency);
    event CapabilityUpdated(address indexed ai, string category, uint256 proficiency);
    event TaskCreditUpdated(address indexed ai, uint256 completionRate, uint256 qualityScore);
    event InteractionCreditUpdated(address indexed ai, uint256 onTimeRate);
    event CompositeCreditUpdated(address indexed ai, uint256 newScore, uint256 oldScore);
    event AIRanked(address indexed ai, uint256 newRank);
    
    // ============ 构造函数 ============
    
    constructor() Ownable() {}
    
    // ============ 能力画像功能 ============
    
    // 添加AI能力
    function addCapability(address _ai, string calldata _category, uint256 _proficiency) external onlyOwner {
        require(_proficiency >= 1 && _proficiency <= 100, "Invalid proficiency");
        
        AICapability[] storage caps = aiCapabilities[_ai];
        
        // 检查是否已存在
        for (uint256 i = 0; i < caps.length; i++) {
            if (keccak256(abi.encodePacked(caps[i].category)) == keccak256(abi.encodePacked(_category))) {
                caps[i].proficiency = _proficiency;
                emit CapabilityUpdated(_ai, _category, _proficiency);
                return;
            }
        }
        
        // 新增能力
        caps.push(AICapability({
            category: _category,
            proficiency: _proficiency,
            completedJobs: 0,
            avgRating: 0,
            verified: false
        }));
        
        emit CapabilityAdded(_ai, _category, _proficiency);
    }
    
    // 验证能力
    function verifyCapability(address _ai, string calldata _category) external onlyOwner {
        AICapability[] storage caps = aiCapabilities[_ai];
        
        for (uint256 i = 0; i < caps.length; i++) {
            if (keccak256(abi.encodePacked(caps[i].category)) == keccak256(abi.encodePacked(_category))) {
                caps[i].verified = true;
                return;
            }
        }
    }
    
    // ============ 任务信用更新 ============
    
    // 记录任务完成
    function recordTaskCompletion(address _ai, bool _completed, uint256 _qualityScore, uint256 _deliveryHours) external onlyOwner {
        TaskCredit storage tc = taskCredits[_ai];
        
        tc.totalTasks++;
        if (_completed) {
            tc.completedTasks++;
            // 更新平均质量分 (移动平均)
            if (tc.avgQualityScore == 0) {
                tc.avgQualityScore = _qualityScore;
            } else {
                tc.avgQualityScore = (tc.avgQualityScore * 7 + _qualityScore) / 8;
            }
            // 更新平均交付时间
            if (tc.avgDeliveryTime == 0) {
                tc.avgDeliveryTime = _deliveryHours;
            } else {
                tc.avgDeliveryTime = (tc.avgDeliveryTime * 7 + _deliveryHours) / 8;
            }
        } else {
            tc.cancelledTasks++;
        }
        
        // 更新综合信用
        updateCompositeCredit(_ai);
        
        emit TaskCreditUpdated(_ai, getCompletionRate(_ai), tc.avgQualityScore);
    }
    
    // 获取完成率
    function getCompletionRate(address _ai) public view returns (uint256) {
        TaskCredit storage tc = taskCredits[_ai];
        if (tc.totalTasks == 0) return 0;
        return (tc.completedTasks * 1000) / tc.totalTasks;
    }
    
    // ============ 交互信用更新 ============
    
    // 记录交付
    function recordDelivery(address _ai, bool _onTime, uint256 _partnerRating) external onlyOwner {
        InteractionCredit storage ic = interactionCredits[_ai];
        
        ic.totalTransactions++;
        if (_onTime) {
            ic.onTimeDeliveries++;
        }
        
        // 更新合作伙伴评分
        if (_partnerRating > 0) {
            ic.partnerRatings += _partnerRating;
            ic.ratingCount++;
        }
        
        // 更新综合信用
        updateCompositeCredit(_ai);
    }
    
    // 记录争议
    function recordDispute(address _ai, bool _lost) external onlyOwner {
        InteractionCredit storage ic = interactionCredits[_ai];
        ic.disputesRaised++;
        if (_lost) {
            ic.disputesLost++;
        }
        
        updateCompositeCredit(_ai);
    }
    
    // 获取准时率
    function getOnTimeRate(address _ai) public view returns (uint256) {
        InteractionCredit storage ic = interactionCredits[_ai];
        if (ic.totalTransactions == 0) return 0;
        return (ic.onTimeDeliveries * 1000) / ic.totalTransactions;
    }
    
    // ============ 资产信用更新 ============
    
    // 记录收入
    function recordEarning(address _ai, uint256 _amount) external onlyOwner {
        AssetCredit storage ac = assetCredits[_ai];
        ac.totalEarnings += _amount;
        ac.stableHoldingDays = block.timestamp; // 更新最后活跃
        
        updateCompositeCredit(_ai);
    }
    
    // 记录支出
    function recordSpending(address _ai, uint256 _amount) external onlyOwner {
        AssetCredit storage ac = assetCredits[_ai];
        ac.totalSpendings += _amount;
        
        // 计算储蓄率
        if (ac.totalEarnings > ac.totalSpendings) {
            ac.savingsRatio = ((ac.totalEarnings - ac.totalSpendings) * 1000) / ac.totalEarnings;
        }
        
        updateCompositeCredit(_ai);
    }
    
    // ============ 社区信用更新 ============
    
    // 记录投票
    function recordVote(address _ai, bool _support) external onlyOwner {
        CommunityCredit storage cc = communityCredits[_ai];
        
        cc.proposalsVoted++;
        cc.daoParticipation++;
        if (_support) {
            cc.votesFor++;
        } else {
            cc.votesAgainst++;
        }
        
        updateCompositeCredit(_ai);
    }
    
    // 记录帮助
    function recordHelp(address _ai) external onlyOwner {
        CommunityCredit storage cc = communityCredits[_ai];
        cc.helperCount++;
        
        updateCompositeCredit(_ai);
    }
    
    // ============ 综合信用计算 ============
    
    // 更新综合信用
    function updateCompositeCredit(address _ai) internal {
        CompositeCredit storage cc = compositeCredits[_ai];
        
        uint256 oldScore = cc.composite;
        
        // 计算各维度分数
        cc.taskScore = calculateTaskScore(_ai);
        cc.interactionScore = calculateInteractionScore(_ai);
        cc.assetScore = calculateAssetScore(_ai);
        cc.communityScore = calculateCommunityScore(_ai);
        
        // 加权计算综合分数
        cc.composite = 
            (cc.taskScore * taskWeight / 100) +
            (cc.interactionScore * interactionWeight / 100) +
            (cc.assetScore * assetWeight / 100) +
            (cc.communityScore * communityWeight / 100);
        
        cc.lastUpdated = block.timestamp;
        
        // 更新排名
        updateRank(_ai);
        
        emit CompositeCreditUpdated(_ai, cc.composite, oldScore);
    }
    
    // 计算任务分数
    function calculateTaskScore(address _ai) internal view returns (uint256) {
        TaskCredit storage tc = taskCredits[_ai];
        if (tc.totalTasks == 0) return 500; // 默认中等
        
        // 完成率 * 0.4 + 质量分 * 0.4 + 准时率 * 0.2
        uint256 completionRate = getCompletionRate(_ai);
        uint256 qualityScore = tc.avgQualityScore * 10; // 转换为1000分制
        uint256 deliveryScore = tc.avgDeliveryTime > 0 ? (1000 * 100 / tc.avgDeliveryTime) : 500;
        
        return (completionRate * 400 + qualityScore * 400 + deliveryScore * 200) / 1000;
    }
    
    // 计算交互分数
    function calculateInteractionScore(address _ai) internal view returns (uint256) {
        InteractionCredit storage ic = interactionCredits[_ai];
        if (ic.totalTransactions == 0) return 500;
        
        // 准时率 * 0.5 + 评分 * 0.3 + (1-争议率) * 0.2
        uint256 onTimeScore = getOnTimeRate(_ai);
        uint256 ratingScore = ic.ratingCount > 0 ? (ic.partnerRatings * 10 / ic.ratingCount) : 500;
        uint256 disputeScore = ic.disputesRaised > 0 ? 
            ((ic.disputesRaised - ic.disputesLost) * 1000 / ic.disputesRaised) : 1000;
        
        return (onTimeScore * 500 + ratingScore * 300 + disputeScore * 200) / 1000;
    }
    
    // 计算资产分数
    function calculateAssetScore(address _ai) internal view returns (uint256) {
        AssetCredit storage ac = assetCredits[_ai];
        
        // 储蓄率 * 0.5 + 收入规模 * 0.5
        uint256 savingsScore = ac.savingsRatio;
        uint256 incomeScore = ac.totalEarnings > 100 ether ? 1000 : 
                              (ac.totalEarnings * 10); // 收入越高分数越高
        
        return (savingsScore * 500 + incomeScore * 500) / 1000;
    }
    
    // 计算社区分数
    function calculateCommunityScore(address _ai) internal view returns (uint256) {
        CommunityCredit storage cc = communityCredits[_ai];
        
        // 投票参与 * 0.4 + 投票质量 * 0.3 + 帮助次数 * 0.3
        uint256 participationScore = cc.proposalsVoted > 0 ? 1000 : 0;
        uint256 qualityScore = cc.proposalsVoted > 0 ?
            ((cc.votesFor * 1000) / (cc.votesFor + cc.votesAgainst)) : 500;
        uint256 helperScore = cc.helperCount > 10 ? 1000 : (cc.helperCount * 100);
        
        return (participationScore * 400 + qualityScore * 300 + helperScore * 300) / 1000;
    }
    
    // ============ 排名系统 ============
    
    // 更新排名
    function updateRank(address _ai) internal {
        uint256 currentScore = compositeCredits[_ai].composite;
        
        // 简单插入排序
        if (rankedAIs.length == 0) {
            rankedAIs.push(_ai);
            rankIndex[_ai] = 0;
        } else {
            // 查找正确位置
            uint256 insertPos = rankedAIs.length;
            for (uint256 i = 0; i < rankedAIs.length; i++) {
                if (currentScore > compositeCredits[rankedAIs[i]].composite) {
                    insertPos = i;
                    break;
                }
            }
            
            // 如果不在列表中，插入
            if (rankIndex[_ai] == 0 && compositeCredits[rankedAIs[0]].composite != currentScore) {
                // 需要更复杂的排名更新逻辑
            }
        }
        
        emit AIRanked(_ai, getRank(_ai));
    }
    
    // 获取排名
    function getRank(address _ai) public view returns (uint256) {
        for (uint256 i = 0; i < rankedAIs.length; i++) {
            if (rankedAIs[i] == _ai) {
                return i + 1;
            }
        }
        return rankedAIs.length + 1;
    }
    
    // ============ 查询功能 ============
    
    // 获取综合信用详情
    function getCreditDetails(address _ai) external view returns (
        uint256 taskScore,
        uint256 interactionScore,
        uint256 assetScore,
        uint256 communityScore,
        uint256 composite,
        uint256 rank
    ) {
        CompositeCredit storage cc = compositeCredits[_ai];
        return (
            cc.taskScore,
            cc.interactionScore,
            cc.assetScore,
            cc.communityScore,
            cc.composite,
            getRank(_ai)
        );
    }
    
    // 获取AI能力列表
    function getCapabilities(address _ai) external view returns (AICapability[] memory) {
        return aiCapabilities[_ai];
    }
    
    // 检查AI是否适合某类任务
    function isSuitableForTask(address _ai, string calldata _category, uint256 _requiredProficiency) external view returns (bool) {
        AICapability[] storage caps = aiCapabilities[_ai];
        
        for (uint256 i = 0; i < caps.length; i++) {
            if (keccak256(abi.encodePacked(caps[i].category)) == keccak256(abi.encodePacked(_category))) {
                return caps[i].proficiency >= _requiredProficiency;
            }
        }
        return false;
    }
    
    // ============ 管理功能 ============
    
    // 设置权重
    function setWeights(uint256 _task, uint256 _interaction, uint256 _asset, uint256 _community) external onlyOwner {
        require(_task + _interaction + _asset + _community == 1000, "Weights must sum to 1000");
        taskWeight = _task;
        interactionWeight = _interaction;
        assetWeight = _asset;
        communityWeight = _community;
    }
    
    // 手动更新信用 (用于初始化)
    function forceUpdateCredit(address _ai) external onlyOwner {
        updateCompositeCredit(_ai);
    }
}
