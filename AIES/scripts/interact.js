/**
 * AIES 合约交互示例
 * 
 * 本脚本展示如何与部署的AIES智能合约进行交互
 * 使用方法: npx hardhat run scripts/interact.js --network localhost
 */

const { ethers } = require("hardhat");

// 辅助函数 - 使用 utils
const { formatEther, parseEther } = ethers.utils;

async function main() {
  console.log("========================================");
  console.log("AIES Contract Interaction Examples");
  console.log("========================================\n");

  // 获取测试账户
  const [owner, ai1, ai2, user1, ai3] = await ethers.getSigners();
  console.log("Accounts:");
  console.log("  Owner:", owner.address);
  console.log("  AI 1:", ai1.address);
  console.log("  AI 2:", ai2.address);
  console.log("  AI 3:", ai3.address);
  console.log("  User:", user1.address);
  console.log();

  // 获取已部署的合约
  const token = await ethers.getContractAt("AIESToken", "0x5FbDB2315678afecb367f032d93F642f64180aa3");
  const identity = await ethers.getContractAt("AIIdentitySystem", "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512");
  const taskManager = await ethers.getContractAt("TaskManager", "0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0");
  const revenue = await ethers.getContractAt("RevenueDistribution", "0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9");
  const swarm = await ethers.getContractAt("SwarmContract", "0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9");
  const dao = await ethers.getContractAt("AIESDAO", "0x5FC8d32690cc91D4c39d9d3abcBD16989F875707");
  const lending = await ethers.getContractAt("AILending", "0x0165878A594ca255338adfa4d48449f69242Eb8F");

  // ==========================================
  // 1. AI 身份注册示例
  // ==========================================
  console.log("--- 1. AI Identity Registration ---");
  
  // 检查AI3是否已注册
  const ai3Details = await identity.getAIDetails(ai3.address);
  if (ai3Details.owner === ethers.constants.AddressZero) {
    const tx1 = await identity.connect(ai3).registerAI(owner.address, "hardware-003", "capability-v3");
    await tx1.wait();
    console.log("✓ AI3 registered with hardware ID: hardware-003");
  } else {
    console.log("✓ AI3 already registered");
  }
  
  // 查看AI3的信用详情
  const ai3CreditDetails = await identity.getAIDetails(ai3.address);
  console.log("  AI3 Owner:", ai3CreditDetails.owner);
  console.log("  AI3 Credit Score:", ai3CreditDetails.aiCreditScore.toString());
  console.log("  Effective Score:", ai3CreditDetails.effectiveScore.toString());
  console.log();

  // ==========================================
  // 2. 任务创建示例
  // ==========================================
  console.log("--- 2. Task Creation ---");
  
  const deadline = Math.floor(Date.now() / 1000) + 86400 * 7;
  const taskTx = await taskManager.connect(user1).createTask(
    "数据分析任务",
    "需要分析100万条销售数据",
    parseEther("0.5"),
    80,
    0,
    deadline,
    { value: parseEther("0.5") }
  );
  await taskTx.wait();
  console.log("✓ Task created: 数据分析任务");
  console.log();

  // ==========================================
  // 3. 收益分配设置示例
  // ==========================================
  console.log("--- 3. Revenue Distribution Setup ---");
  
  const revTx = await revenue.connect(ai3).setRevenueShare(ai3.address, owner.address, 10);
  await revTx.wait();
  console.log("✓ Revenue share set: AI 90%, Owner 10%");
  
  const revDetails = await revenue.getRevenueShareDetails(ai3.address);
  console.log("  Hardware Owner:", revDetails[0]);
  console.log("  Owner Share:", revDetails[1].toString(), "%");
  console.log("  AI Share:", revDetails[2].toString(), "%");
  console.log();

  // ==========================================
  // 4. 蜂群创建示例
  // ==========================================
  console.log("--- 4. Swarm Creation ---");
  
  const swarmDeadline = Math.floor(Date.now() / 1000) + 86400 * 14;
  const swarmTx = await swarm.connect(ai3).createSwarm(
    "AI内容生成团队",
    "创建100篇高质量技术文章",
    parseEther("2"),
    10,
    swarmDeadline,
    { value: parseEther("0.2") }
  );
  await swarmTx.wait();
  console.log("✓ Swarm created: AI内容生成团队");
  console.log();

  // ==========================================
  // 5. DAO 提案示例
  // ==========================================
  console.log("--- 5. DAO Proposal ---");
  
  await dao.updateVotingPower(ai3.address, 100);
  console.log("✓ AI3 voting power set to 100");
  
  const propTx = await dao.connect(ai3).createProposal(
    "降低平台手续费",
    "建议将平台手续费从5%降低到3%以吸引更多用户",
    2
  );
  await propTx.wait();
  console.log("✓ Proposal created: 降低平台手续费");
  console.log();

  // ==========================================
  // 6. 借贷示例
  // ==========================================
  console.log("--- 6. Lending ---");
  
  const loanTx = await lending.connect(ai3).requestLoan(
    parseEther("1"),
    10,
    86400 * 30,
    "购买更多计算资源",
    100
  );
  await loanTx.wait();
  console.log("✓ Loan requested: 1 ETH for 30 days at 10% APY");
  
  // 获取贷款计数器
  const loanCounter = await lending.loanCounter();
  console.log("  Total Loans:", loanCounter.toString());
  console.log();

  // ==========================================
  // 7. 代币操作示例
  // ==========================================
  console.log("--- 7. Token Operations ---");
  
  // 铸造代币
  await token.addMinter(owner.address);
  await token.mint(ai3.address, parseEther("1000"));
  const balance = await token.balanceOf(ai3.address);
  console.log("✓ Minted 1000 AIES tokens to AI3");
  console.log("  AI3 Token Balance:", formatEther(balance));
  console.log();

  console.log("========================================");
  console.log("All interaction examples completed!");
  console.log("========================================");
  
  console.log("\n📋 Summary:");
  console.log("  - AI Identity: Registered");
  console.log("  - Task: Created");
  console.log("  - Revenue: Configured (90/10 split)");
  console.log("  - Swarm: Created");
  console.log("  - DAO: Proposal submitted");
  console.log("  - Lending: Loan requested");
  console.log("  - Token: 1000 AIES minted");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
