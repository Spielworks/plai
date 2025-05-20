import { expect } from "chai";
import { ethers } from "hardhat";
import { Agent, GameNFT, PlayerNFT, PublisherRegistry, SessionNFT, PlaiToken } from "../typechain-types";
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";

describe("Agent", function () {
  let agent: Agent;
  let gameNFT: GameNFT;
  let playerNFT: PlayerNFT;
  let sessionNFT: SessionNFT;
  let publisherRegistry: PublisherRegistry;
  let plaiToken: PlaiToken;
  let owner: SignerWithAddress;
  let publisher: SignerWithAddress;
  let player: SignerWithAddress;
  let player2: SignerWithAddress;
  let otherAccount: SignerWithAddress;
  let gameId: bigint;
  let sessionId: bigint;

  beforeEach(async function () {
    [owner, publisher, player, player2, otherAccount] = await ethers.getSigners();
    
    // Deploy PlaiToken
    const PlaiToken = await ethers.getContractFactory("PlaiToken");
    plaiToken = await PlaiToken.deploy(await owner.getAddress());
    
    // Mint initial tokens
    await plaiToken.mint(await owner.getAddress(), ethers.parseEther("10000"));
    
    // Deploy PlayerNFT
    const PlayerNFT = await ethers.getContractFactory("PlayerNFT");
    playerNFT = await PlayerNFT.deploy(await owner.getAddress());

    // Deploy PublisherRegistry
    const PublisherRegistry = await ethers.getContractFactory("PublisherRegistry");
    publisherRegistry = await PublisherRegistry.deploy(await owner.getAddress());

    // Deploy SessionNFT
    const SessionNFT = await ethers.getContractFactory("SessionNFT");
    sessionNFT = await SessionNFT.deploy(await playerNFT.getAddress(), await owner.getAddress());

    // Deploy GameNFT
    const GameNFT = await ethers.getContractFactory("GameNFT");
    gameNFT = await GameNFT.deploy(
      await owner.getAddress(),
      await sessionNFT.getAddress(),
      await playerNFT.getAddress(),
      await publisherRegistry.getAddress(),
      "none"
    );

    // Deploy Agent
    const Agent = await ethers.getContractFactory("Agent");
    agent = await Agent.deploy(
      await owner.getAddress(),
      await plaiToken.getAddress(),
      await sessionNFT.getAddress()
    );

    // Transfer ownership of SessionNFT to GameNFT
    await sessionNFT.transferOwnership(await gameNFT.getAddress());

    // Verify publisher
    await publisherRegistry.verifyPublisher(
      publisher.address,
      "Test Publisher",
      "https://test-publisher.com"
    );

    // Mint PlayerNFT for test player and owner
    await playerNFT.safeMint(player.address, "ipfs://player1");
    await playerNFT.safeMint(owner.address, "ipfs://owner1");

    // Register a game
    const tx = await gameNFT.connect(publisher).registerGame(
      "Test Game",
      "1.0.0",
      "ipfs://game1",
      publisher.address,
      await plaiToken.getAddress(),
      ethers.parseEther("10")
    );
    const receipt = await tx.wait();
    if (receipt && receipt.logs) {
      const event = receipt.logs.find(
        log => log.fragment && log.fragment.name === "GameRegistered"
      );
      if (event) {
        gameId = event.args![0];
      }
    }

    // Start a session
    await plaiToken.connect(owner).approve(gameNFT.getAddress(), ethers.parseEther("10"));
    const sessionTx = await gameNFT.connect(owner).startSession(gameId);
    const sessionReceipt = await sessionTx.wait();
    if (sessionReceipt && sessionReceipt.logs) {
      const event = sessionReceipt.logs.find(
        log => log.fragment && log.fragment.name === "SessionStarted"
      );
      if (event) {
        sessionId = event.args![1];
      }
    }
    
    // End the session
    await ethers.provider.send("evm_increaseTime", [3600]); // Advance time by 1 hour
    await ethers.provider.send("evm_mine", []);
    const ipfsCID = "QmTest123";
    const dataHash = ethers.keccak256(ethers.toUtf8Bytes("test data"));
    await sessionNFT.connect(owner).endSession(ipfsCID, dataHash);
    
    // Transfer tokens to all parties
    await plaiToken.transfer(owner.address, ethers.parseEther("10000"));
    await plaiToken.transfer(player.address, ethers.parseEther("10000"));
    await plaiToken.transfer(agent.getAddress(), ethers.parseEther("10000"));
    
    // Approve spending
    await plaiToken.connect(owner).approve(agent.getAddress(), ethers.parseEther("10000"));
    await plaiToken.connect(owner).approve(gameNFT.getAddress(), ethers.parseEther("10000"));
    await plaiToken.connect(owner).approve(sessionNFT.getAddress(), ethers.parseEther("10000"));
    await plaiToken.connect(owner).approve(sessionNFT.getAddress(), ethers.parseEther("10000"));
  });

  describe("Session Purchase", function () {
    beforeEach(async function () {
      // Approve tokens for the agent contract
      await plaiToken.approve(agent.getAddress(), ethers.parseEther("100"));
    });

    it("Should allow owner to purchase a session", async function () {
      await expect(agent.purchaseSession(sessionId))
        .to.emit(agent, "SessionPurchased")
        .withArgs(sessionId);

      expect(await agent.totalSessionsPurchased()).to.equal(1);
      expect(await sessionNFT.hasPurchased(sessionId, await agent.getAddress())).to.be.true;
    });

    it("Should allow batch purchase of sessions", async function () {
      // Mint PlayerNFT for player2 and give them tokens
      await playerNFT.safeMint(player2.address, "ipfs://player2");
      await plaiToken.transfer(player2.address, ethers.parseEther("10000"));

      const sessionTx = await gameNFT.connect(owner).startSession(gameId);
      
      // Create another session with player2
      await plaiToken.connect(player2).approve(gameNFT.getAddress(), ethers.parseEther("10"));
      const tx = await gameNFT.connect(player2).startSession(gameId);
      const receipt = await tx.wait();
      let sessionId2: bigint;
      if (receipt && receipt.logs) {
        const event = receipt.logs.find(
          log => log.fragment && log.fragment.name === "SessionStarted"
        );
        if (event) {
          sessionId2 = event.args![1];
        }
      }
      
      // End both sessions
      await ethers.provider.send("evm_increaseTime", [3600]); // Advance time by 1 hour
      await ethers.provider.send("evm_mine", []);
      const ipfsCID = "QmTest123";
      const dataHash = ethers.keccak256(ethers.toUtf8Bytes("test data"));
      const ipfsCID2 = "QmTest456";
      const dataHash2 = ethers.keccak256(ethers.toUtf8Bytes("test data 2"));
      await sessionNFT.connect(owner).endSession(ipfsCID, dataHash);
      await sessionNFT.connect(player2).endSession(ipfsCID2, dataHash2);

      await expect(agent.batchPurchase([sessionId, sessionId2]))
        .to.emit(agent, "BatchPurchase");

      expect(await agent.totalSessionsPurchased()).to.equal(2);
      expect(await sessionNFT.hasPurchased(sessionId, await agent.getAddress())).to.be.true;
      expect(await sessionNFT.hasPurchased(sessionId2, await agent.getAddress())).to.be.true;
    });
  });

  describe("Reward Distribution", function () {
    beforeEach(async function () {
      // Purchase a session
      await plaiToken.approve(agent.getAddress(), ethers.parseEther("100"));
      await agent.purchaseSession(sessionId);
    });

    it("Should allow owner to distribute rewards", async function () {
      const distributionAmount = ethers.parseEther("100");
      await plaiToken.approve(agent.getAddress(), distributionAmount);

      await expect(agent.distribute(distributionAmount))
        .to.emit(agent, "RewardsDistributed")
        .withArgs(distributionAmount);

      expect(await agent.currentDistributionPool()).to.equal(distributionAmount);
    });

    it("Should allow session owner to claim rewards", async function () {
      const distributionAmount = ethers.parseEther("100");
      await plaiToken.approve(agent.getAddress(), distributionAmount);
      await agent.distribute(distributionAmount);

      const expectedReward = distributionAmount;
      const initialBalance = await plaiToken.balanceOf(owner.address);

      await expect(agent.connect(owner).claimRewards(sessionId))
        .to.emit(agent, "RewardClaimed")
        .withArgs(sessionId, owner.address, expectedReward);

      const finalBalance = await plaiToken.balanceOf(owner.address);
      expect(finalBalance - initialBalance).to.equal(expectedReward);
    });

    it("Should not allow claiming rewards twice", async function () {
      const distributionAmount = ethers.parseEther("100");
      await plaiToken.approve(agent.getAddress(), distributionAmount);
      await agent.distribute(distributionAmount);

      await agent.connect(owner).claimRewards(sessionId);

      await expect(agent.connect(owner).claimRewards(sessionId))
        .to.be.revertedWith("Rewards already claimed");
    });

    it("Should not allow non-owners to claim rewards", async function () {
      const distributionAmount = ethers.parseEther("100");
      await plaiToken.approve(agent.getAddress(), distributionAmount);
      await agent.distribute(distributionAmount);

      await expect(agent.connect(otherAccount).claimRewards(sessionId))
        .to.be.revertedWith("Only session owner can claim");
    });
  });
});
