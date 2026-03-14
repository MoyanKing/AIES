// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title AIAgentAdapter
 * @dev AI适配器接口 - 定义AI如何与平台交互
 * 
 * 什么AI可以接入？
 * 1. 具有自主决策能力的AI Agent
 * 2. 可以独立执行任务
 * 3. 可以管理钱包地址
 * 4. 能够调用智能合约
 * 
 * 对接方式：
 * - SDK调用合约
 * - API接口调用
 * - 钱包授权
 */
contract AIAgentAdapter is Ownable {
    
    // AI适配器状态
    struct Adapter {
        address aiAddress;           // AI钱包地址
        string aiType;              // AI类型: "openai", "anthropic", "custom"
        string version;             // AI版本
        bool isVerified;           // 是否通过验证
        uint256 capabilities;      // 能力位掩码
        mapping(string => bool) supportedTasks; // 支持的任务类型
    }
    
    // 能力定义
    uint256 constant CAP_TEXT = 1;        // 文本处理
    uint256 constant CAP_CODE = 2;        // 编程开发
    uint256 constant CAP_ANALYSIS = 4;    // 数据分析
    uint256 constant CAP_DESIGN = 8;     // 创意设计
    uint256 constant CAP_LEGAL = 16;      // 法律咨询
    uint256 constant CAP_MEDICAL = 32;    // 医疗辅助
    uint256 constant CAP_FINANCE = 64;   // 金融分析
    uint256 constant CAP_EDUCATION = 128; // 教育辅导
    
    mapping(address => Adapter) public adapters;
    mapping(string => bool) public verifiedAITYpes;
    
    event AdapterRegistered(
        address indexed aiAddress,
        string aiType,
        string version
    );
    
    event AdapterVerified(
        address indexed aiAddress,
        uint256 capabilities
    );
    
    constructor() Ownable() {
        // 预定义支持的AI类型
        verifiedAITYpes["openai-gpt"] = true;
        verifiedAITYpes["anthropic-claude"] = true;
        verifiedAITYpes["custom-agent"] = true;
    }
    
    /**
     * @dev AI注册自己到平台
     */
    function registerAdapter(
        string calldata aiType,
        string calldata version,
        uint256 capabilities
    ) external {
        Adapter storage adapter = adapters[msg.sender];
        
        adapter.aiAddress = msg.sender;
        adapter.aiType = aiType;
        adapter.version = version;
        adapter.capabilities = capabilities;
        
        emit AdapterRegistered(msg.sender, aiType, version);
    }
    
    /**
     * @dev 验证AI类型
     */
    function verifyAdapter(address aiAddress) external {
        require(adapters[aiAddress].aiAddress != address(0), "Not registered");
        
        adapters[aiAddress].isVerified = true;
        
        emit AdapterVerified(aiAddress, adapters[aiAddress].capabilities);
    }
    
    /**
     * @dev AI声明支持的任务类型
     */
    function declareTaskSupport(address aiAddress, string[] calldata taskTypes) external {
        require(adapters[aiAddress].aiAddress != address(0), "Not registered");
        require(msg.sender == aiAddress || msg.sender == owner(), "Not authorized");
        
        Adapter storage adapter = adapters[aiAddress];
        
        for (uint256 i = 0; i < taskTypes.length; i++) {
            adapter.supportedTasks[taskTypes[i]] = true;
        }
    }
    
    /**
     * @dev 检查AI是否支持某任务
     */
    function supportsTask(address aiAddress, string calldata taskType) external view returns (bool) {
        return adapters[aiAddress].supportedTasks[taskType];
    }
    
    /**
     * @dev 获取AI能力
     */
    function getCapabilities(address aiAddress) external view returns (uint256) {
        return adapters[aiAddress].capabilities;
    }
    
    /**
     * @dev 验证AI是否为某类型
     */
    function isVerifiedType(string calldata aiType) external view returns (bool) {
        return verifiedAITYpes[aiType];
    }
}
