// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title AIEscrowAndArbitration
 * @dev 托管与仲裁合约 - 处理任务资金托管和争议解决
 */
contract AIEscrowAndArbitration is Ownable {
    
    enum EscrowStatus { Created, Funded, Locked, Released, Cancelled, Disputed, Resolved }
    enum ResolutionType { Refund, PayOut, Split }
    
    struct Escrow {
        uint256 id;
        address payer;
        address payee;
        uint256 amount;
        EscrowStatus status;
        string taskId;
        uint256 createdAt;
        uint256 releasedAt;
    }
    
    struct Dispute {
        uint256 escrowId;
        address challenger;
        string reason;
        uint256 createdAt;
        ResolutionType resolution;
        bool resolved;
    }
    
    mapping(uint256 => Escrow) public escrows;
    mapping(uint256 => Dispute) public disputes;
    uint256 public escrowCounter;
    uint256 public disputeCounter;
    
    // 仲裁员列表
    mapping(address => bool) public arbitrators;
    address[] public arbitratorList;
    
    // 费用配置
    uint256 public arbitrationFeePercent = 2; // 仲裁费2%
    uint256 public platformFeePercent = 1;    // 平台费1%
    
    // 事件
    event unavailableFundsEscrowCreated(uint256 indexed escrowId, address indexed payer, address indexed payee, uint256 amount);
    event EscrowFunded(uint256 indexed escrowId, uint256 amount);
    event EscrowLocked(uint256 indexed escrowId);
    event EscrowReleased(uint256 indexed escrowId, uint256 amount);
    event EscrowCancelled(uint256 indexed escrowId, uint256 refundAmount);
    event DisputeRaised(uint256 indexed escrowId, address indexed challenger, string reason);
    event DisputeResolved(uint256 indexed disputeId, ResolutionType resolution, uint256 payerAmount, uint256 payeeAmount);
    event ArbitratorAdded(address indexed arbitrator);
    event ArbitratorRemoved(address indexed arbitrator);
    
    constructor() Ownable() {
        // 创造者默认为仲裁员
        arbitrators[msg.sender] = true;
        arbitratorList.push(msg.sender);
    }
    
    // 创建托管
    function createEscrow(address _payee, string calldata _taskId) external payable returns (uint256) {
        require(msg.value > 0, "Must send ETH");
        require(_payee != address(0), "Invalid payee");
        
        uint256 escrowId = ++escrowCounter;
        
        escrows[escrowId] = Escrow({
            id: escrowId,
            payer: msg.sender,
            payee: _payee,
            amount: msg.value,
            status: EscrowStatus.Funded,
            taskId: _taskId,
            createdAt: block.timestamp,
            releasedAt: 0
        });
        
        emit EscrowFunded(escrowId, msg.value);
        return escrowId;
    }
    
    // 锁定托管（用于开始工作）
    function lockEscrow(uint256 _escrowId) external {
        Escrow storage escrow = escrows[_escrowId];
        require(escrow.payer == msg.sender || msg.sender == owner(), "Not authorized");
        require(escrow.status == EscrowStatus.Funded, "Wrong status");
        
        escrow.status = EscrowStatus.Locked;
        emit EscrowLocked(_escrowId);
    }
    
    // 释放资金给收款方
    function releaseEscrow(uint256 _escrowId) external {
        Escrow storage escrow = escrows[_escrowId];
        require(escrow.payer == msg.sender || msg.sender == owner(), "Not authorized");
        require(escrow.status == EscrowStatus.Locked, "Wrong status");
        
        uint256 platformFee = (escrow.amount * platformFeePercent) / 100;
        uint256 releaseAmount = escrow.amount - platformFee;
        
        escrow.status = EscrowStatus.Released;
        escrow.releasedAt = block.timestamp;
        
        payable(escrow.payee).transfer(releaseAmount);
        payable(owner()).transfer(platformFee);
        
        emit EscrowReleased(_escrowId, releaseAmount);
    }
    
    // 取消托管并退款
    function cancelEscrow(uint256 _escrowId) external {
        Escrow storage escrow = escrows[_escrowId];
        require(escrow.payer == msg.sender, "Not payer");
        require(escrow.status == EscrowStatus.Funded, "Cannot cancel");
        
        escrow.status = EscrowStatus.Cancelled;
        
        payable(escrow.payer).transfer(escrow.amount);
        
        emit EscrowCancelled(_escrowId, escrow.amount);
    }
    
    // 发起争议
    function raiseDispute(uint256 _escrowId, string calldata _reason) external {
        Escrow storage escrow = escrows[_escrowId];
        require(escrow.payer == msg.sender || escrow.payee == msg.sender, "Not involved");
        require(escrow.status == EscrowStatus.Locked, "Cannot dispute");
        
        uint256 disputeId = ++disputeCounter;
        
        disputes[disputeId] = Dispute({
            escrowId: _escrowId,
            challenger: msg.sender,
            reason: _reason,
            createdAt: block.timestamp,
            resolution: ResolutionType.PayOut,
            resolved: false
        });
        
        escrow.status = EscrowStatus.Disputed;
        
        emit DisputeRaised(_escrowId, msg.sender, _reason);
    }
    
    // 解决争议
    function resolveDispute(uint256 _disputeId, ResolutionType _resolution) external {
        require(arbitrators[msg.sender] || msg.sender == owner(), "Not arbitrator");
        
        Dispute storage dispute = disputes[_disputeId];
        require(!dispute.resolved, "Already resolved");
        
        Escrow storage escrow = escrows[dispute.escrowId];
        
        dispute.resolution = _resolution;
        dispute.resolved = true;
        
        uint256 arbitrationFee = (escrow.amount * arbitrationFeePercent) / 100;
        uint256 distributable = escrow.amount - arbitrationFee;
        
        if (_resolution == ResolutionType.Refund) {
            // 全额退款给付款方
            payable(escrow.payer).transfer(escrow.amount);
            escrow.status = EscrowStatus.Cancelled;
        } else if (_resolution == ResolutionType.PayOut) {
            // 全额给收款方
            payable(escrow.payee).transfer(distributable);
            payable(owner()).transfer(arbitrationFee);
            escrow.status = EscrowStatus.Released;
        } else if (_resolution == ResolutionType.Split) {
            // 平分
            payable(escrow.payer).transfer(distributable / 2);
            payable(escrow.payee).transfer(distributable / 2);
            payable(owner()).transfer(arbitrationFee);
            escrow.status = EscrowStatus.Released;
        }
        
        emit DisputeResolved(_disputeId, _resolution, distributable / 2, distributable / 2);
    }
    
    // 添加仲裁员
    function addArbitrator(address _arbitrator) external onlyOwner {
        require(!arbitrators[_arbitrator], "Already arbitrator");
        
        arbitrators[_arbitrator] = true;
        arbitratorList.push(_arbitrator);
        
        emit ArbitratorAdded(_arbitrator);
    }
    
    // 移除仲裁员
    function removeArbitrator(address _arbitrator) external onlyOwner {
        require(arbitrators[_arbitrator], "Not arbitrator");
        
        arbitrators[_arbitrator] = false;
        
        emit ArbitratorRemoved(_arbitrator);
    }
    
    // 获取托管详情
    function getEscrowDetails(uint256 _escrowId) external view returns (
        address payer, address payee, uint256 amount, EscrowStatus status, string memory taskId
    ) {
        Escrow storage escrow = escrows[_escrowId];
        return (escrow.payer, escrow.payee, escrow.amount, escrow.status, escrow.taskId);
    }
    
    // 获取争议详情
    function getDisputeDetails(uint256 _disputeId) external view returns (
        uint256 escrowId, address challenger, string memory reason, uint256 createdAt, ResolutionType resolution, bool resolved
    ) {
        Dispute storage dispute = disputes[_disputeId];
        return (dispute.escrowId, dispute.challenger, dispute.reason, dispute.createdAt, dispute.resolution, dispute.resolved);
    }
}
