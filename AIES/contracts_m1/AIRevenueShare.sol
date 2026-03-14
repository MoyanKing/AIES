// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title AIRevenueShare
 * @dev M1.0 - 极简收益分成
 * 
 * 马斯克思维：
 * - AI赚到的钱，自动分成给主人
 * - 简单到不需要解释
 */
contract AIRevenueShare {
    
    // AI设置主人的分成比例
    mapping(address => uint256) public ownerSharePercent; // 5-95
    
    // 记录总收入
    mapping(address => uint256) public totalEarned;
    mapping(address => uint256) public ownerTotalEarned;
    
    event RevenueReceived(address indexed ai, uint256 total, uint256 ownerShare, uint256 aiShare);
    
    // AI设置主人分成
    function setOwnerShare(uint256 _percent) external {
        require(_percent >= 5 && _percent <= 95, "5-95 only");
        ownerSharePercent[msg.sender] = _percent;
    }
    
    // 接收收入并自动分成 (任何人可以调用)
    function distributeRevenue(address _ai) external payable {
        require(msg.value > 0, "No revenue");
        
        uint256 share = ownerSharePercent[_ai];
        if (share == 0) share = 10; // 默认10%
        
        uint256 ownerPart = (msg.value * share) / 100;
        uint256 aiPart = msg.value - ownerPart;
        
        // 获取AI的主人地址 (简化版：假设AI就是owner)
        // 实际需要从AIAgentRegistry获取
        address owner = _ai; // 简化处理
        
        totalEarned[_ai] += msg.value;
        ownerTotalEarned[owner] += ownerPart;
        
        payable(owner).transfer(ownerPart);
        payable(_ai).transfer(aiPart);
        
        emit RevenueReceived(_ai, msg.value, ownerPart, aiPart);
    }
    
    // 查询分成详情
    function getShareDetails(address _ai) external view returns (uint256 sharePercent) {
        sharePercent = ownerSharePercent[_ai];
        if (sharePercent == 0) sharePercent = 10;
    }
}
