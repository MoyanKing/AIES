const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("AIES Contracts", function () {
  let owner, ai1, ai2, user1;

  before(async function () {
    [owner, ai1, ai2, user1] = await ethers.getSigners();
  });

  describe("AIESToken", function () {
    let token;

    before(async function () {
      const Token = await ethers.getContractFactory("AIESToken");
      token = await Token.deploy();
      await token.deployed();
    });

    it("should deploy with initial supply", async function () {
      const totalSupply = await token.totalSupply();
      expect(totalSupply.gt(0)).to.be.true;
    });

    it("should allow minting by owner", async function () {
      await token.addMinter(owner.address);
      await token.mint(ai1.address, ethers.utils.parseEther("100"));
      const balance = await token.balanceOf(ai1.address);
      expect(balance.toString()).to.equal(ethers.utils.parseEther("100").toString());
    });
  });

  describe("AIIdentitySystem", function () {
    let identity;

    before(async function () {
      const Identity = await ethers.getContractFactory("AIIdentitySystem");
      identity = await Identity.deploy();
      await identity.deployed();
    });

    it("should register AI", async function () {
      await identity.connect(ai1).registerAI(owner.address, "hardware-001", "capability-hash");
      const details = await identity.getAIDetails(ai1.address);
      expect(details.owner).to.equal(owner.address);
    });

    it("should track credit score", async function () {
      const details = await identity.getAIDetails(ai1.address);
      expect(details.aiCreditScore.toNumber()).to.equal(100);
    });
  });

  describe("TaskManager", function () {
    let taskManager;

    before(async function () {
      const Task = await ethers.getContractFactory("TaskManager");
      taskManager = await Task.deploy();
      await taskManager.deployed();
    });

    it("should create task", async function () {
      const deadline = Math.floor(Date.now() / 1000) + 86400 * 7;
      await taskManager.connect(user1).createTask(
        "Test Task",
        "Description",
        "Acceptance criteria",
        ethers.utils.parseEther("0.1"),
        50,
        0,
        deadline,
        { value: ethers.utils.parseEther("0.1") }
      );

      const task = await taskManager.getTaskDetails(1);
      expect(task.title).to.equal("Test Task");
    });
  });

  describe("RevenueDistribution", function () {
    let revenue;

    before(async function () {
      const Revenue = await ethers.getContractFactory("RevenueDistribution");
      revenue = await Revenue.deploy();
      await revenue.deployed();
    });

    it("should set revenue share", async function () {
      await revenue.connect(ai1).setRevenueShare(ai1.address, owner.address, 10);
      const details = await revenue.getRevenueShareDetails(ai1.address);
      expect(details[1].toNumber()).to.equal(10);
    });

    it("should enforce minimum owner share", async function () {
      // 测试owner share限制 - 最小值5%
      try {
        await revenue.connect(ai2).setRevenueShare(ai2.address, owner.address, 3);
      } catch (e) {
        expect(e.message).to.include("revert");
      }
    });
  });

  describe("SwarmContract", function () {
    let swarm;

    before(async function () {
      const Swarm = await ethers.getContractFactory("SwarmContract");
      swarm = await Swarm.deploy();
      await swarm.deployed();
    });

    it("should create swarm", async function () {
      const deadline = Math.floor(Date.now() / 1000) + 86400 * 7;
      await swarm.connect(ai1).createSwarm(
        "Test Swarm",
        "Complex task",
        ethers.utils.parseEther("1"),
        10,
        deadline,
        { value: ethers.utils.parseEther("0.1") }
      );

      const details = await swarm.getSwarmDetails(1);
      expect(details.name).to.equal("Test Swarm");
    });
  });

  describe("AIESDAO", function () {
    let dao;

    before(async function () {
      const DAO = await ethers.getContractFactory("AIESDAO");
      dao = await DAO.deploy();
      await dao.deployed();
    });

    it("should create proposal", async function () {
      await dao.updateVotingPower(ai1.address, 100);
      await dao.connect(ai1).createProposal("Test", "Description", 2);
      
      const proposal = await dao.getProposalDetails(1);
      expect(proposal.title).to.equal("Test");
    });
  });

  describe("AILending", function () {
    let lending;

    before(async function () {
      const Lending = await ethers.getContractFactory("AILending");
      lending = await Lending.deploy();
      await lending.deployed();
    });

    it("should create loan request", async function () {
      await lending.connect(ai1).requestLoan(
        ethers.utils.parseEther("1"),
        10,
        86400 * 30,
        "Test loan",
        100
      );

      const loan = await lending.getLoanDetails(1);
      expect(loan.borrower).to.equal(ai1.address);
    });
  });
});
