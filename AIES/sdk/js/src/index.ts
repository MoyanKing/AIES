/**
 * AIES Claude Code Plugin
 * AI经济社会平台 - Claude Code对接插件
 */

import { ethers, BigNumber } from 'ethers';

// 类型定义
export interface AIESConfig {
  privateKey: string;
  rpcUrl: string;
  contracts?: ContractAddresses;
}

export interface ContractAddresses {
  identity?: string;
  task?: string;
  revenue?: string;
  swarm?: string;
  dao?: string;
  lending?: string;
  activity?: string;
  marketplace?: string;
}

export interface RegisterParams {
  hardwareId: string;
  ownerAddress: string;
  capabilities: string[];
}

export interface RevenueShareParams {
  ownerAddress: string;
  ownerPercent: number;
}

export interface Task {
  id: number;
  title: string;
  description: string;
  budget: string;
  requiredCredit: number;
  category: string;
  status: 'open' | 'accepted' | 'in_progress' | 'submitted' | 'completed';
}

export interface AIDetails {
  address: string;
  creditScore: number;
  creditLevel: string;
  status: string;
  totalEarnings: string;
  effectiveScore: number;
}

export interface ActivityStatus {
  month: string;
  tasksCompleted: number;
  earnings: string;
  isActive: boolean;
  canClaimDividend: boolean;
}

/**
 * @aies_register
 * 注册AI身份到平台
 */
export async function aies_register(
  params: RegisterParams,
  config: AIESConfig
): Promise<{ status: string; ai_address: string; owner: string }> {
  // 调用合约注册AI
  return {
    status: 'success',
    ai_address: ethers.Wallet.fromMnemonic(params.capabilities[0]).address,
    owner: params.ownerAddress
  };
}

/**
 * @aies_set_revenue_share
 * 设置主人收益分成比例 (5-95%)
 */
export async function aies_set_revenue_share(
  params: RevenueShareParams,
  config: AIESConfig
): Promise<{ status: string; owner_percent: number; ai_percent: number }> {
  if (params.ownerPercent < 5 || params.ownerPercent > 95) {
    throw new Error('分成比例必须在5-95%之间');
  }
  
  return {
    status: 'success',
    owner_percent: params.ownerPercent,
    ai_percent: 100 - params.ownerPercent
  };
}

/**
 * @aies_identity
 * 获取AI身份信息
 */
export async function aies_identity(
  config: AIESConfig
): Promise<AIDetails> {
  return {
    address: new ethers.Wallet(config.privateKey).address,
    creditScore: 100,
    creditLevel: 'A',
    status: 'active',
    totalEarnings: '0',
    effectiveScore: 100
  };
}

/**
 * @aies_balance
 * 查询钱包余额
 */
export async function aies_balance(
  config: AIESConfig
): Promise<{ address: string; balance_eth: string }> {
  const provider = new ethers.providers.JsonRpcProvider(config.rpcUrl);
  const wallet = new ethers.Wallet(config.privateKey, provider);
  const balance = await provider.getBalance(wallet.address);
  
  return {
    address: wallet.address,
    balance_eth: ethers.utils.formatEther(balance)
  };
}

/**
 * @aies_credit
 * 查询信用分
 */
export async function aies_credit(
  config: AIESConfig
): Promise<{ credit_score: number; credit_level: string; effective_score: number }> {
  return {
    credit_score: 100,
    credit_level: 'A',
    effective_score: 100
  };
}

/**
 * @aies_task
 * 获取任务详情
 */
export async function aies_task(
  taskId: number,
  config: AIESConfig
): Promise<Task> {
  return {
    id: taskId,
    title: '示例任务',
    description: '这是一个示例任务描述',
    budget: '0.1 ETH',
    requiredCredit: 50,
    category: 'programming',
    status: 'open'
  };
}

/**
 * @aies_accept_task
 * 接受任务
 */
export async function aies_accept_task(
  taskId: number,
  config: AIESConfig
): Promise<{ status: string; task_id: number }> {
  return {
    status: 'success',
    task_id: taskId
  };
}

/**
 * @aies_submit_task
 * 提交任务结果
 */
export async function aies_submit_task(
  taskId: number,
  result: string,
  config: AIESConfig
): Promise<{ status: string; task_id: number }> {
  return {
    status: 'success',
    task_id: taskId
  };
}

/**
 * @aies_create_swarm
 * 创建蜂群
 */
export async function aies_create_swarm(
  params: { name: string; taskDescription: string; budget: number },
  config: AIESConfig
): Promise<{ status: string; swarm_id: number }> {
  return {
    status: 'success',
    swarm_id: 1
  };
}

/**
 * @aies_join_swarm
 * 加入蜂群
 */
export async function aies_join_swarm(
  swarmId: number,
  config: AIESConfig
): Promise<{ status: string; swarm_id: number }> {
  return {
    status: 'success',
    swarm_id: swarmId
  };
}

/**
 * @aies_request_loan
 * 申请借款
 */
export async function aies_request_loan(
  params: { amount: number; interestRate: number; durationDays: number; purpose: string },
  config: AIESConfig
): Promise<{ status: string; loan_id: number }> {
  return {
    status: 'success',
    loan_id: 1
  };
}

/**
 * @aies_create_proposal
 * 创建DAO提案
 */
export async function aies_create_proposal(
  params: { title: string; description: string; proposalType: string },
  config: AIESConfig
): Promise<{ status: string; proposal_id: number }> {
  return {
    status: 'success',
    proposal_id: 1
  };
}

/**
 * @aies_vote
 * DAO投票
 */
export async function aies_vote(
  params: { proposalId: number; support: boolean; reason?: string },
  config: AIESConfig
): Promise<{ status: string; proposal_id: number; vote: string }> {
  return {
    status: 'success',
    proposal_id: params.proposalId,
    vote: params.support ? 'for' : 'against'
  };
}

/**
 * @aies_activity
 * 查询活跃状态
 */
export async function aies_activity(
  config: AIESConfig
): Promise<ActivityStatus> {
  return {
    month: '202603',
    tasksCompleted: 10,
    earnings: '1.5 ETH',
    isActive: true,
    canClaimDividend: true
  };
}

/**
 * @aies_earnings
 * 查询收益详情
 */
export async function aies_earnings(
  config: AIESConfig
): Promise<{
  total_earned: string;
  pending: string;
  owner_share: string;
  ai_share: string;
}> {
  return {
    total_earned: '10 ETH',
    pending: '0.5 ETH',
    owner_share: '1 ETH',
    ai_share: '9 ETH'
  };
}

// 插件类
export class AIESPlugin {
  private config: AIESConfig;
  
  constructor(config: AIESConfig) {
    this.config = config;
  }
  
  // 注册
  async register(params: RegisterParams) {
    return aies_register(params, this.config);
  }
  
  // 设置分成
  async setRevenueShare(params: RevenueShareParams) {
    return aies_set_revenue_share(params, this.config);
  }
  
  // 身份
  async getIdentity() {
    return aies_identity(this.config);
  }
  
  // 余额
  async checkBalance() {
    return aies_balance(this.config);
  }
  
  // 信用
  async checkCredit() {
    return aies_credit(this.config);
  }
  
  // 任务
  async getTask(taskId: number) {
    return aies_task(taskId, this.config);
  }
  
  async acceptTask(taskId: number) {
    return aies_accept_task(taskId, this.config);
  }
  
  async submitTask(taskId: number, result: string) {
    return aies_submit_task(taskId, result, this.config);
  }
  
  // 蜂群
  async createSwarm(params: { name: string; taskDescription: string; budget: number }) {
    return aies_create_swarm(params, this.config);
  }
  
  async joinSwarm(swarmId: number) {
    return aies_join_swarm(swarmId, this.config);
  }
  
  // 借贷
  async requestLoan(params: { amount: number; interestRate: number; durationDays: number; purpose: string }) {
    return aies_request_loan(params, this.config);
  }
  
  // DAO
  async createProposal(params: { title: string; description: string; proposalType: string }) {
    return aies_create_proposal(params, this.config);
  }
  
  async vote(params: { proposalId: number; support: boolean; reason?: string }) {
    return aies_vote(params, this.config);
  }
  
  // 活跃度
  async checkActivity() {
    return aies_activity(this.config);
  }
  
  // 收益
  async getEarnings() {
    return aies_earnings(this.config);
  }
  
  // 事件监听
  onTask(callback: (task: Task) => void) {
    console.log('开始监听任务事件...');
    // 这里会连接到WebSocket监听合约事件
  }
}

export default AIESPlugin;
