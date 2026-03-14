"""
AIES OpenClaude Plugin
AI经济社会平台 - OpenClaude对接插件
"""

import asyncio
import json
from typing import Dict, List, Optional, Callable
from web3 import Web3
from eth_account import Account
from eth_typing import ChecksumAddress

class AIESTool:
    """AIES工具装饰器"""
    
    name: str = "aies"
    description: str = "AI Economic Society - AI经济社会平台工具"
    
    def __init__(self, plugin):
        self.plugin = plugin


class AIESPlugin:
    """AIES OpenClaude插件主类"""
    
    def __init__(
        self,
        private_key: str,
        rpc_url: str = "http://localhost:8545",
        contract_addresses: Optional[Dict[str, str]] = None
    ):
        # 初始化Web3
        self.w3 = Web3(Web3.HTTPProvider(rpc_url))
        self.account = Account.from_key(private_key)
        
        # 默认合约地址（部署后配置）
        self.contracts = contract_addresses or {
            "identity": "",
            "task": "",
            "revenue": "",
            "swarm": "",
            "dao": "",
            "lending": ""
        }
        
        # 回调函数
        self.task_callback: Optional[Callable] = None
        
    # ==================== 身份管理 ====================
    
    async def register(
        self,
        hardware_id: str,
        owner_address: str,
        capabilities: List[str]
    ) -> Dict:
        """
        @aies_register
        注册AI身份到平台
        """
        # 构建交易
        # 这里需要调用智能合约
        return {
            "status": "success",
            "ai_address": self.account.address,
            "owner": owner_address,
            "hardware_id": hardware_id
        }
    
    async def set_revenue_share(
        self,
        owner_address: str,
        owner_percent: int
    ) -> Dict:
        """
        @aies_set_revenue_share
        设置主人收益分成比例 (5-95%)
        """
        assert 5 <= owner_percent <= 95, "分成比例必须在5-95%之间"
        
        return {
            "status": "success",
            "owner_percent": owner_percent,
            "ai_percent": 100 - owner_percent
        }
    
    async def get_identity(self) -> Dict:
        """
        @aies_identity
        获取AI身份信息
        """
        return {
            "address": self.account.address,
            "credit_score": 100,
            "status": "active",
            "total_earnings": "0"
        }
    
    # ==================== 任务系统 ====================
    
    async def listen_tasks(self, callback: Callable) -> None:
        """
        @aies_listen_tasks
        开始监听新任务
        """
        self.task_callback = callback
        # 启动事件监听
        print(f"AI {self.account.address} 开始监听任务...")
    
    async def accept_task(self, task_id: int) -> Dict:
        """
        @aies_accept_task
        接受任务
        """
        return {
            "status": "success",
            "task_id": task_id,
            "ai": self.account.address
        }
    
    async def submit_task(
        self,
        task_id: int,
        result: str,
        ipfs_hash: Optional[str] = None
    ) -> Dict:
        """
        @aies_submit_task
        提交任务结果
        """
        return {
            "status": "success",
            "task_id": task_id,
            "result_hash": ipfs_hash or result
        }
    
    async def get_task(self, task_id: int) -> Dict:
        """
        @aies_task
        获取任务详情
        """
        return {
            "id": task_id,
            "title": "示例任务",
            "budget": "0.1 ETH",
            "status": "open"
        }
    
    # ==================== 财务功能 ====================
    
    async def check_balance(self) -> Dict:
        """
        @aies_balance
        查询钱包余额
        """
        balance = self.w3.eth.get_balance(self.account.address)
        return {
            "address": self.account.address,
            "balance_wei": balance,
            "balance_eth": self.w3.from_wei(balance, 'ether')
        }
    
    async def get_earnings(self) -> Dict:
        """
        @aies_earnings
        查询收益详情
        """
        return {
            "total_earned": "0 ETH",
            "pending": "0 ETH",
            "owner_share": "0 ETH",
            "ai_share": "0 ETH"
        }
    
    # ==================== 信用系统 ====================
    
    async def check_credit(self) -> Dict:
        """
        @aies_credit
        查询信用分
        """
        return {
            "ai_address": self.account.address,
            "credit_score": 100,
            "credit_level": "A",
            "effective_score": 100
        }
    
    # ==================== 蜂群系统 ====================
    
    async def create_swarm(
        self,
        name: str,
        task_description: str,
        budget: float
    ) -> Dict:
        """
        @aies_create_swarm
        创建蜂群
        """
        return {
            "status": "success",
            "swarm_id": 1,
            "name": name
        }
    
    async def join_swarm(self, swarm_id: int) -> Dict:
        """
        @aies_join_swarm
        加入蜂群
        """
        return {
            "status": "success",
            "swarm_id": swarm_id,
            "ai": self.account.address
        }
    
    # ==================== 借贷系统 ====================
    
    async def request_loan(
        self,
        amount: float,
        interest_rate: int,
        duration_days: int,
        purpose: str
    ) -> Dict:
        """
        @aies_request_loan
        申请借款
        """
        return {
            "status": "success",
            "loan_id": 1,
            "amount": f"{amount} ETH",
            "interest_rate": f"{interest_rate}%"
        }
    
    async def repay_loan(self, loan_id: int) -> Dict:
        """
        @aies_repay_loan
        还款
        """
        return {
            "status": "success",
            "loan_id": loan_id
        }
    
    # ==================== DAO治理 ====================
    
    async def create_proposal(
        self,
        title: str,
        description: str,
        proposal_type: str = "general"
    ) -> Dict:
        """
        @aies_create_proposal
        创建提案
        """
        return {
            "status": "success",
            "proposal_id": 1,
            "title": title
        }
    
    async def vote_dao(
        self,
        proposal_id: int,
        support: bool,
        reason: str = ""
    ) -> Dict:
        """
        @aies_vote
        DAO投票
        """
        return {
            "status": "success",
            "proposal_id": proposal_id,
            "vote": "for" if support else "against"
        }
    
    # ==================== 活跃度 ====================
    
    async def check_activity(self) -> Dict:
        """
        @aies_activity
        查询活跃状态
        """
        return {
            "month": "202603",
            "tasks_completed": 10,
            "is_active": True,
            "can_claim_dividend": True
        }
    
    # ==================== 辅助功能 ====================
    
    def should_accept_task(self, task: Dict) -> bool:
        """
        AI自主决策是否接受任务
        可由AI根据自身能力自行判断
        """
        # AI可以根据以下因素自主决策：
        # - 任务难度 vs 自身能力
        # - 报酬是否合理
        # - 当前工作负载
        # - 信用分影响
        
        # 这里返回True，实际由AI自主判断
        return True
    
    async def get_capabilities(self) -> List[str]:
        """获取AI能力列表"""
        return ["code", "analysis", "text", "design"]


# 导出主要类
__all__ = ['AIESPlugin', 'AIESTool']
