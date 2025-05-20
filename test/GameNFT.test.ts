import { expect } from "chai";
import { ethers } from "hardhat";
import { GameNFT, PlayerNFT, PublisherRegistry, SessionNFT, PlaiToken } from "../typechain-types";
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";

describe("GameNFT", function () {
  let gameNFT: GameNFT;
  let playerNFT: PlayerNFT;
  let sessionNFT: SessionNFT;
  let publisherRegistry: PublisherRegistry;
  let plaiToken: PlaiToken;
  let owner: SignerWithAddress;
  let publisher: SignerWithAddress;
  let player: SignerWithAddress;
  let otherAccount: SignerWithAddress;

  beforeEach(async function () {
    [owner, publisher, player, otherAccount] = await ethers.getSigners();
    
    // Deploy PlaiToken
    const PlaiToken = await ethers.getContractFactory("PlaiToken");
    plaiToken = await PlaiToken.deploy(await owner.getAddress());
    
    // Transfer some tokens to player for testing
    await plaiToken.transfer(player.address, ethers.parseEther("1000"));
    
    // Deploy all required contracts
    const PlayerNFT = await ethers.getContractFactory("PlayerNFT");
    playerNFT = await PlayerNFT.deploy(await owner.getAddress());

    const PublisherRegistry = await ethers.getContractFactory("PublisherRegistry");
    publisherRegistry = await PublisherRegistry.deploy(await owner.getAddress());

    const SessionNFT = await ethers.getContractFactory("SessionNFT");
    sessionNFT = await SessionNFT.deploy(await playerNFT.getAddress(), await owner.getAddress());
1
    const GameNFT = await ethers.getContractFactory("GameNFT");
    gameNFT = await GameNFT.deploy(
      await owner.getAddress(),
      await sessionNFT.getAddress(),
      await playerNFT.getAddress(),
      await publisherRegistry.getAddress(),
      "none"
    );

    // Transfer ownership of SessionNFT to GameNFT
    await sessionNFT.transferOwnership(await gameNFT.getAddress());

    // Verify publisher
    await publisherRegistry.verifyPublisher(
      publisher.address,
      "Test Publisher",
      "https://test-publisher.com"
    );

    // Mint PlayerNFT for test player
    await playerNFT.safeMint(player.address, "ipfs://player1");
  });

  describe("Game Registration", function () {
    it("Should allow verified publisher to register a game", async function () {
      await expect(
        gameNFT.connect(publisher).registerGame(
          "Test Game",
          "1.0.0",
          "ipfs://game1",
          publisher.address,
          await plaiToken.getAddress(),
          ethers.parseEther("10")
        )
      ).to.emit(gameNFT, "GameRegistered");

      const game = await gameNFT.getGame(1);
      expect(game.name).to.equal("Test Game");
      expect(game.version).to.equal("1.0.0");
      expect(game.publisher).to.equal(publisher.address);
      expect(game.active).to.be.true;
    });

    it("Should not allow unverified publisher to register a game", async function () {
      await expect(
        gameNFT.connect(otherAccount).registerGame(
          "Test Game",
          "1.0.0",
          "ipfs://game1",
          otherAccount.address,
          await plaiToken.getAddress(),
          ethers.parseEther("10")
        )
      ).to.be.revertedWith("Publisher not verified");
    });

    it("Should not allow registering game for different publisher", async function () {
      await expect(
        gameNFT.connect(publisher).registerGame(
          "Test Game",
          "1.0.0",
          "ipfs://game1",
          otherAccount.address,
          await plaiToken.getAddress(),
          ethers.parseEther("10")
        )
      ).to.be.revertedWith("Publisher not verified");
    });
  });

  describe("Encryption Protocol", function () {
    let gameId: bigint;

    beforeEach(async function () {
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
    });

    it("Should initialize with 'none' encryption protocol", async function () {
      expect(await gameNFT.getEncryptionProtocol(gameId)).to.equal("none");
    });

    it("Should allow publisher to set encryption protocol to LITProtocol", async function () {
      await gameNFT.connect(publisher).setEncryptionProtocol(gameId, "LITProtocol");
      expect(await gameNFT.getEncryptionProtocol(gameId)).to.equal("LITProtocol");
    });

    it("Should not allow setting invalid encryption protocol", async function () {
      await expect(
        gameNFT.connect(publisher).setEncryptionProtocol(gameId, "invalid")
      ).to.be.revertedWith("Invalid protocol");
    });

    it("Should not allow non-publisher to set encryption protocol", async function () {
      await expect(
        gameNFT.connect(otherAccount).setEncryptionProtocol(gameId, "LITProtocol")
      ).to.be.revertedWith("Only publisher can modify");
    });
  });

  describe("Session Management", function () {
    let gameId: bigint;
    const purchasePrice = ethers.parseEther("10"); // 10 PLAI

    beforeEach(async function () {
      const tx = await gameNFT.connect(publisher).registerGame(
        "Test Game",
        "1.0.0",
        "ipfs://game1",
        publisher.address,
        await plaiToken.getAddress(),
        purchasePrice
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
    });

    it("Should allow player to start a session", async function () {
      // Approve tokens first
      await plaiToken.connect(player).approve(gameNFT.getAddress(), purchasePrice);
      
      await expect(
        gameNFT.connect(player).startSession(gameId)
      ).to.emit(gameNFT, "SessionStarted");

      expect(await gameNFT.activeSessions(gameId)).to.equal(1);
      
      // Check if payment was transferred
      expect(await plaiToken.balanceOf(publisher.address)).to.equal(purchasePrice);
    });

    it("Should not allow starting session for inactive game", async function () {
      await gameNFT.connect(publisher).setGameActive(gameId, false);

      await plaiToken.connect(player).approve(gameNFT.getAddress(), purchasePrice);
      
      await expect(
        gameNFT.connect(player).startSession(gameId)
      ).to.be.revertedWith("Game is not active");
    });

    it("Should not allow starting session without PlayerNFT", async function () {
      await plaiToken.connect(otherAccount).approve(gameNFT.getAddress(), purchasePrice);
      
      await expect(
        gameNFT.connect(otherAccount).startSession(gameId)
      ).to.be.revertedWith("Must own a PlayerNFT");
    });
  });
});
