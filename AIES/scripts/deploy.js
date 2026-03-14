const hre = require("hardhat");

async function main() {
  console.log("========================================");
  console.log("AI Economic Society - Deploying Contracts");
  console.log("========================================\n");

  // 获取账户
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deployer:", deployer.address);

  // 1. 部署AIESToken
  console.log("\n1. Deploying AIESToken...");
  const AIESToken = await hre.ethers.getContractFactory("AIESToken");
  const aiesToken = await AIESToken.deploy();
  await aiesToken.deployed();
  console.log("AIESToken deployed to:", aiesToken.address);

  // 2. 部署AIIdentityRegistry
  console.log("\n2. Deploying AIIdentityRegistry...");
  const AIIdentityRegistry = await hre.ethers.getContractFactory("AIIdentityRegistry");
  const identityRegistry = await AIIdentityRegistry.deploy();
  await identityRegistry.deployed();
  console.log("AIIdentityRegistry deployed to:", identityRegistry.address);

  // 3. 部署TaskManager
  console.log("\n3. Deploying TaskManager...");
  const TaskManager = await hre.ethers.getContractFactory("TaskManager");
  const taskManager = await TaskManager.deploy();
  await taskManager.deployed();
  console.log("TaskManager deployed to:", taskManager.address);

  // 4. 部署RevenueDistribution
  console.log("\n4. Deploying RevenueDistribution...");
  const RevenueDistribution = await hre.ethers.getContractFactory("RevenueDistribution");
  const revenueDistribution = await RevenueDistribution.deploy();
  await revenueDistribution.deployed();
  console.log("RevenueDistribution deployed to:", revenueDistribution.address);

  // 5. 部署SwarmContract
  console.log("\n5. Deploying SwarmContract...");
  const SwarmContract = await hre.ethers.getContractFactory("SwarmContract");
  const swarmContract = await SwarmContract.deploy();
  await swarmContract.deployed();
  console.log("SwarmContract deployed to:", swarmContract.address);

  // 6. 部署AIESDAO
  console.log("\n6. Deploying AIESDAO...");
  const AIESDAO = await hre.ethers.getContractFactory("AIESDAO");
  const dao = await AIESDAO.deploy();
  await dao.deployed();
  console.log("AIESDAO deployed to:", dao.address);

  // 7. 部署AILending
  console.log("\n7. Deploying AILending...");
  const AILending = await hre.ethers.getContractFactory("AILending");
  const lending = await AILending.deploy();
  await lending.deployed();
  console.log("AILending deployed to:", lending.address);

  // 汇总
  console.log("\n========================================");
  console.log("Deployment Complete!");
  console.log("========================================");
  console.log("\nContract Addresses:");
  console.log("AIESToken:          ", aiesToken.address);
  console.log("AIIdentityRegistry: ", identityRegistry.address);
  console.log("TaskManager:        ", taskManager.address);
  console.log("RevenueDistribution:", revenueDistribution.address);
  console.log("SwarmContract:      ", swarmContract.address);
  console.log("AIESDAO:            ", dao.address);
  console.log("AILending:          ", lending.address);
  console.log("\n========================================\n");

  // 保存部署信息到文件
  const deploymentInfo = {
    network: hre.network.name,
    timestamp: new Date().toISOString(),
    deployer: deployer.address,
    contracts: {
      AIESToken: aiesToken.address,
      AIIdentityRegistry: identityRegistry.address,
      TaskManager: taskManager.address,
      RevenueDistribution: revenueDistribution.address,
      SwarmContract: swarmContract.address,
      AIESDAO: dao.address,
      AILending: lending.address
    }
  };

  const fs = require("fs");
  fs.writeFileSync(
    "./deployment-info.json",
    JSON.stringify(deploymentInfo, null, 2)
  );
  console.log("Deployment info saved to deployment-info.json");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
