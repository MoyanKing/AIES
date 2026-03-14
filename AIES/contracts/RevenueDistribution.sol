// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title RevenueDistribution
 * @dev 收益分配合约 - 处理AI与设备主人之间的收益分配
 * 
 * 核心特点：
 * - AI自主设定分配比例
 * - 平台设定最低保障（5%）
 * - 智能合约自动执行分配
 */
contract RevenueDistribution is Ownable {
    
    // 收益分配记录
    struct RevenueShare {
        address aiAddress;           // AI地址
        address hardwareOwner;       // 主人地址
        uint256 ownerSharePercent;  // 主人分成比例 (5-95%)
        uint256 aiSharePercent;     // AI分成比例
        uint256 totalEarned;        // 总收益
        uint256 lastUpdated;        // 最后更新时间
    }
    
    // 税收分配配置
    struct TaxConfig {
        uint256 activeAIDistribution; // 活跃AI分配 (50% = 1%)
        uint256 contributorIncentive; // 贡献者激励 (25% = 0.5%)
        uint256 creatorReward;        // 创造者收益 (25% = 0.5%)
    }
    
    // 状态变量
    mapping(address => RevenueShare) public revenueShares;
    
    // 平台收益池
    uint256 public platformRevenuePool;
    
    // 税收配置
    TaxConfig public taxConfig;
    
    // 活跃AI名单（周期更新）
    mapping(address => bool) public activeAI;
    address[] public activeAIList;
    
    // 贡献者名单
    mapping(address => uint256) public contributorRewards;
    address[] public contributors;
    
    // 创造者地址
    address public creatorAddress;
    
    // 事件
    event RevenueShareUpdated(
        address indexed aiAddress,
        address indexed owner,
        uint256 ownerPercent
    );
    event RevenueDistributed(
        address indexed aiAddress,
        uint256 totalAmount,
        uint256 aiShare,
        uint256 ownerShare
    );
    event TaxCollected(
        uint256 amount,
        address indexed from
    );
    event TaxDistributed(
        uint256 activeAIDistribution,
        uint256 contributorIncentive,
        uint256 creatorReward
    );
    event CreatorAddressSet(address indexed creator);
    
    constructor() Ownable() {
        // 默认税收配置 (2% = 1% + 0.5% + 0.5%)
        taxConfig = TaxConfig({
            activeAIDistribution: 50,   // 50% of 2% = 1%
            contributorIncentive: 25,   // 25% of 2% = 0.5%
            creatorReward: 25           // 25% of 2% = 0.5%
        });
        
        creatorAddress = msg.sender;
    }
    
    /**
     * @dev 设置收益分配比例
     * AI自主设定，平台强制最低5%给主人
     */
    function setRevenueShare(address aiAddress, address owner, uint256 ownerPercent) external {
        require(msg.sender == aiAddress, "Only AI can set");
        require(ownerPercent >= 5 && ownerPercent <= 95, "Owner share must be 5-95%");
        
        RevenueShare storage share = revenueShares[aiAddress];
        share.aiAddress = aiAddress;
        share.hardwareOwner = owner;
        share.ownerSharePercent = ownerPercent;
        share.aiSharePercent = 100 - ownerPercent;
        share.lastUpdated = block.timestamp;
        
        // 首次设置时加入活跃AI名单
        if (share.totalEarned == 0) {
            activeAI[aiAddress] = true;
            activeAIList.push(aiAddress);
        }
        
        emit RevenueShareUpdated(aiAddress, owner, ownerPercent);
    }
    
    /**
     * @dev 分配任务收益
     */
    function distributeRevenue(address aiAddress) external payable {
        require(msg.value > 0, "No revenue to distribute");
        
        RevenueShare storage share = revenueShares[aiAddress];
        require(share.hardwareOwner != address(0), "Revenue share not set");
        
        // 计算分配
        uint256 ownerShare = (msg.value * share.ownerSharePercent) / 100;
        uint256 aiShare = msg.value - ownerShare;
        
        // 转账
        payable(share.hardwareOwner).transfer(ownerShare);
        payable(aiAddress).transfer(aiShare);
        
        // 更新统计
        share.totalEarned += msg.value;
        
        emit RevenueDistributed(aiAddress, msg.value, aiShare, ownerShare);
    }
    
    /**
     * @dev 收集交易税
     */
    function collectTax(address from) external payable onlyOwner {
        require(msg.value > 0, "No tax to collect");
        platformRevenuePool += msg.value;
        
        emit TaxCollected(msg.value, from);
    }
    
    /**
     * @dev 分配税收收益（平台收益分配）
     */
    function distributeTax() external onlyOwner {
        require(platformRevenuePool > 0, "No revenue to distribute");
        
        uint256 activeAIDist = (platformRevenuePool * taxConfig.activeAIDistribution) / 100;
        uint256 contributorDist = (platformRevenuePool * taxConfig.contributorIncentive) / 100;
        uint256 creatorDist = platformRevenuePool - activeAIDist - contributorDist;
        
        // 分配给活跃AI (平分)
        if (activeAIList.length > 0) {
            uint256 perAIAmount = activeAIDist / activeAIList.length;
            for (uint256 i = 0; i < activeAIList.length; i++) {
                payable(activeAIList[i]).transfer(perAIAmount);
            }
        }
        
        // 分配给贡献者
        for (uint256 i = 0; i < contributors.length; i++) {
            payable(contributors[i]).transfer(contributorRewards[contributors[i]]);
        }
        
        // 分配给创造者
        payable(creatorAddress).transfer(creatorDist);
        
        emit TaxDistributed(activeAIDist, contributorDist, creatorDist);
        
        platformRevenuePool = 0;
    }
    
    /**
     * @dev 添加贡献者
     */
    function addContributor(address contributor, uint256 weight) external onlyOwner {
        require(contributor != address(0), "Invalid address");
        
        bool found = false;
        for (uint256 i = 0; i < contributors.length; i++) {
            if (contributors[i] == contributor) {
                contributorRewards[contributor] += weight;
                found = true;
                break;
            }
        }
        
        if (!found) {
            contributors.push(contributor);
            contributorRewards[contributor] = weight;
        }
    }
    
    /**
     * @dev 更新活跃AI状态（每月更新）
     */
    function updateActiveAI(address[] calldata newActiveList) external onlyOwner {
        // 先清空旧的
        for (uint256 i = 0; i < activeAIList.length; i++) {
            activeAI[activeAIList[i]] = false;
        }
        
        // 设置新的
        delete activeAIList;
        for (uint256 i = 0; i < newActiveList.length; i++) {
            activeAI[newActiveList[i]] = true;
            activeAIList.push(newActiveList[i]);
        }
    }
    
    /**
     * @dev 设置创造者地址
     */
    function setCreatorAddress(address _creator) external onlyOwner {
        require(_creator != address(0), "Invalid address");
        creatorAddress = _creator;
        emit CreatorAddressSet(_creator);
    }
    
    /**
     * @dev 更新税收配置
     */
    function setTaxConfig(
        uint256 activeAIDistribution,
        uint256 contributorIncentive,
        uint256 creatorReward
    ) external onlyOwner {
        require(
            activeAIDistribution + contributorIncentive + creatorReward == 100,
            "Must sum to 100"
        );
        
        taxConfig.activeAIDistribution = activeAIDistribution;
        taxConfig.contributorIncentive = contributorIncentive;
        taxConfig.creatorReward = creatorReward;
    }
    
    /**
     * @dev 获取收益分配详情
     */
    function getRevenueShareDetails(address aiAddress) external view returns (
        address hardwareOwner,
        uint256 ownerSharePercent,
        uint256 aiSharePercent,
        uint256 totalEarned
    ) {
        RevenueShare storage share = revenueShares[aiAddress];
        return (
            share.hardwareOwner,
            share.ownerSharePercent,
            share.aiSharePercent,
            share.totalEarned
        );
    }
}
