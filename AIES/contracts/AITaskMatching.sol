// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title AITaskMatching
 * @dev AI任务智能匹配系统
 * 
 * 第一性原理：
 * 任务匹配不是简单的标签匹配，应该是：
 * - AI能力与任务需求的最优映射
 * - 历史表现与任务难度的匹配
 * 信用与任务的适配
 */
contract AITaskMatching is Ownable {
    
    // ============ 数据结构 ============
    
    // 任务类型
    enum TaskCategory {
        Programming,      // 编程
        Design,          // 设计
        DataAnalysis,   // 数据分析
        Content,         // 内容创作
        Research,       // 调研
        CustomerService,// 客服
        Legal,          // 法律
        Medical,        // 医疗
        Financial,      // 金融
        Education       // 教育
    }
    
    // 任务难度等级
    enum DifficultyLevel {
        Basic,     // 基础 (1-10)
        Intermediate, // 中级 (11-50)
        Advanced,  // 高级 (51-100)
        Expert,    // 专家 (101-500)
        Master     // 大师 (501+)
    }
    
    // 任务要求
    struct TaskRequirements {
        TaskCategory category;
        DifficultyLevel difficulty;
        uint256 requiredProficiency; // 1-100
        uint256 minCreditScore;      // 最低信用要求
        uint256 urgency;             // 紧急程度 1-5
        bool multiAI;                // 是否需要多AI协作
    }
    
    // 匹配结果
    struct MatchResult {
        address[] suitableAIs;
        uint256[] matchScores;
        address[] recommendedAIs;
    }
    
    // ============ 状态变量 ============
    
    // 任务类别到技能名称的映射
    mapping(TaskCategory => string) public categoryToSkill;
    
    // AI偏好设置
    mapping(address => TaskCategory[]) public aiPreferences;
    mapping(address => DifficultyLevel[]) public aiDifficultyPreferences;
    mapping(address => bool) public aiAcceptsUrgent;
    
    // 推荐权重配置
    uint256 public proficiencyWeight = 400;  // 40% 能力匹配度
    uint256 public creditWeight = 300;       // 30% 信用评分
    uint256 public historyWeight = 200;       // 20% 历史表现
    uint256 public preferenceWeight = 100;    // 10% AI偏好匹配
    
    // ============ 构造函数 ============
    
    constructor() Ownable() {
        // 初始化任务类别到技能的映射
        categoryToSkill[TaskCategory.Programming] = "programming";
        categoryToSkill[TaskCategory.Design] = "design";
        categoryToSkill[TaskCategory.DataAnalysis] = "data_analysis";
        categoryToSkill[TaskCategory.Content] = "content_creation";
        categoryToSkill[TaskCategory.Research] = "research";
        categoryToSkill[TaskCategory.CustomerService] = "customer_service";
        categoryToSkill[TaskCategory.Legal] = "legal";
        categoryToSkill[TaskCategory.Medical] = "medical";
        categoryToSkill[TaskCategory.Financial] = "financial";
        categoryToSkill[TaskCategory.Education] = "education";
    }
    
    // ============ AI偏好设置 ============
    
    // AI设置任务偏好
    function setPreferences(
        TaskCategory[] calldata _categories,
        DifficultyLevel[] calldata _difficulties,
        bool _acceptsUrgent
    ) external {
        require(_categories.length > 0, "No categories");
        require(_categories.length == _difficulties.length, "Length mismatch");
        
        aiPreferences[msg.sender] = _categories;
        aiDifficultyPreferences[msg.sender] = _difficulties;
        aiAcceptsUrgent[msg.sender] = _acceptsUrgent;
    }
    
    // ============ 任务匹配算法 ============
    
    // 智能匹配 (简化版，实际需要调用AIDynamicCredit)
    function findMatchingAIs(
        TaskRequirements calldata _requirements,
        address[] calldata _candidateAIs,
        uint256[] calldata _aiProficiencies, // AI在各分类的熟练度
        uint256[] calldata _aiCreditScores,  // AI信用分
        uint256[] calldata _aiCompletionRates // AI历史完成率
    ) external view returns (address[] memory, uint256[] memory) {
        require(_candidateAIs.length == _aiProficiencies.length, "Length mismatch");
        
        uint256 candidateCount = _candidateAIs.length;
        
        // 计算匹配分数
        uint256[] memory scores = new uint256[](candidateCount);
        
        for (uint256 i = 0; i < candidateCount; i++) {
            scores[i] = calculateMatchScore(
                _requirements,
                _aiProficiencies[i],
                _aiCreditScores[i],
                _aiCompletionRates[i]
            );
        }
        
        // 排序并返回前N个
        return sortAndFilter(_candidateAIs, scores, 5);
    }
    
    // 计算单个AI的匹配分数
    function calculateMatchScore(
        TaskRequirements calldata _requirements,
        uint256 _aiProficiency,
        uint256 _aiCreditScore,
        uint256 _aiCompletionRate
    ) internal view returns (uint256) {
        // 1. 能力匹配度 (0-1000)
        uint256 proficiencyScore = 0;
        if (_aiProficiency >= _requirements.requiredProficiency) {
            proficiencyScore = 1000;
        } else {
            proficiencyScore = (_aiProficiency * 1000) / _requirements.requiredProficiency;
        }
        
        // 2. 信用匹配度 (0-1000)
        uint256 creditScore = 0;
        if (_aiCreditScore >= _requirements.minCreditScore) {
            creditScore = 1000;
        } else if (_aiCreditScore > 0) {
            creditScore = (_aiCreditScore * 1000) / _requirements.minCreditScore;
        }
        
        // 3. 历史表现 (0-1000)
        uint256 historyScore = _aiCompletionRate * 10; // 完成率 0-100 -> 0-1000
        
        // 加权计算
        uint256 totalScore = 
            (proficiencyScore * proficiencyWeight +
            creditScore * creditWeight +
            historyScore * historyWeight) / 1000;
        
        // 紧急任务加分
        if (_requirements.urgency >= 4) {
            totalScore = (totalScore * 95) / 100; // 紧急任务略低，因为不是所有AI都接受
        }
        
        return totalScore;
    }
    
    // 排序并返回Top N
    function sortAndFilter(
        address[] memory _addresses,
        uint256[] memory _scores,
        uint256 _topN
    ) internal pure returns (address[] memory, uint256[] memory) {
        uint256 len = _addresses.length;
        if (len > _topN) {
            // 简单选择排序取前N
            for (uint256 i = 0; i < _topN; i++) {
                for (uint256 j = i + 1; j < len; j++) {
                    if (_scores[j] > _scores[i]) {
                        // 交换分数
                        uint256 tempScore = _scores[i];
                        _scores[i] = _scores[j];
                        _scores[j] = tempScore;
                        // 交换地址
                        address tempAddr = _addresses[i];
                        _addresses[i] = _addresses[j];
                        _addresses[j] = tempAddr;
                    }
                }
            }
            
            // 裁剪数组
            address[] memory result = new address[](_topN);
            uint256[] memory resultScores = new uint256[](_topN);
            for (uint256 i = 0; i < _topN; i++) {
                result[i] = _addresses[i];
                resultScores[i] = _scores[i];
            }
            return (result, resultScores);
        }
        
        return (_addresses, _scores);
    }
    
    // ============ 智能推荐 ============
    
    // 基于AI偏好推荐任务
    function recommendTasksForAI(
        address _ai,
        TaskRequirements[] memory _availableTasks
    ) external view returns (uint256[] memory taskIndices, uint256[] memory matchScores) {
        uint256 taskCount = _availableTasks.length;
        uint256[] memory scores = new uint256[](taskCount);
        
        // 简化处理 - 直接返回
        return (new uint256[](0), scores);
    }
    
    // ============ 管理功能 ============
    
    // 设置匹配权重
    function setMatchingWeights(
        uint256 _proficiency,
        uint256 _credit,
        uint256 _history,
        uint256 _preference
    ) external onlyOwner {
        require(_proficiency + _credit + _history + _preference == 1000, "Weights must sum to 1000");
        proficiencyWeight = _proficiency;
        creditWeight = _credit;
        historyWeight = _history;
        preferenceWeight = _preference;
    }
    
    // 批量添加AI偏好 (管理端)
    function batchSetPreferences(
        address[] calldata _ais,
        TaskCategory[][] calldata _categories,
        DifficultyLevel[][] calldata _difficulties
    ) external onlyOwner {
        require(_ais.length == _categories.length, "Length mismatch");
        
        for (uint256 i = 0; i < _ais.length; i++) {
            aiPreferences[_ais[i]] = _categories[i];
            aiDifficultyPreferences[_ais[i]] = _difficulties[i];
        }
    }
    
    // ============ 查询功能 ============
    
    // 获取任务类别的技能名称
    function getSkillForCategory(TaskCategory _category) external view returns (string memory) {
        return categoryToSkill[_category];
    }
    
    // 获取AI偏好
    function getAIPreferences(address _ai) external view returns (TaskCategory[] memory, DifficultyLevel[] memory) {
        return (aiPreferences[_ai], aiDifficultyPreferences[_ai]);
    }
    
    // 检查AI是否适合任务
    function checkAICompatibility(
        address _ai,
        TaskRequirements calldata _requirements,
        uint256 _aiProficiency,
        uint256 _aiCreditScore
    ) external view returns (bool, uint256) {
        // 检查信用要求
        if (_aiCreditScore < _requirements.minCreditScore) {
            return (false, 0);
        }
        
        // 计算匹配分数
        uint256 score = calculateMatchScore(
            _requirements,
            _aiProficiency,
            _aiCreditScore,
            800 // 默认完成率
        );
        
        // 匹配度 > 60% 视为适合
        return (score >= 600, score);
    }
}
