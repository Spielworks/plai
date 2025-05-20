import { expect } from "chai";
import { ethers } from "hardhat";
import { SessionNFT, PlayerNFT, PlaiToken } from "../typechain-types";
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";

describe("SessionNFT", function () {
  let sessionNFT: SessionNFT;
  let playerNFT: PlayerNFT;
  let plaiToken: PlaiToken;
  let owner: SignerWithAddress;
  let player: SignerWithAddress;
  let publisher: SignerWithAddress;
  let gameId: bigint;

  beforeEach(async function () {
    [owner, player, publisher] = await ethers.getSigners();
    
    const PlaiToken = await ethers.getContractFactory("PlaiToken");
    plaiToken = await PlaiToken.deploy(await owner.getAddress());

    const PlayerNFT = await ethers.getContractFactory("PlayerNFT");
    playerNFT = await PlayerNFT.deploy(await owner.getAddress());

    const SessionNFT = await ethers.getContractFactory("SessionNFT");
    sessionNFT = await SessionNFT.deploy(await playerNFT.getAddress(), await owner.getAddress());

    // Mint PlayerNFT for test player
    await playerNFT.safeMint(await player.getAddress(), "ipfs://player1");
    
    gameId = 1n; // Example game ID
  });

  describe("Session Management", function () {
    let sessionId: bigint;
    const purchasePrice = ethers.parseEther("10"); // 10 PLAI

    beforeEach(async function () {
      // Start a session (simulating call from GameNFT)
      const tx = await sessionNFT.startSession(player.address, gameId, publisher.address, purchasePrice, await plaiToken.getAddress());
      const receipt = await tx.wait();
      if (receipt && receipt.logs) {
        const event = receipt.logs.find(
          log => log.fragment && log.fragment.name === "SessionStarted"
        );
        if (event) {
          sessionId = event.args![1];
        }
      }
    });

    it("Should correctly start a session", async function () {
      const session = await sessionNFT.getSession(sessionId);
      expect(session.player).to.equal(player.address);
      expect(session.gameId).to.equal(gameId);
      expect(session.verifier).to.equal(publisher.address);
      expect(session.endTime).to.equal(0);
      expect(session.purchasePrice).to.equal(purchasePrice);
      expect(session.verified).to.be.false;
    });

    it("Should not allow player to have multiple active sessions", async function () {
      await expect(
        sessionNFT.startSession(player.address, gameId, publisher.address, purchasePrice, await plaiToken.getAddress())
      ).to.be.revertedWith("Active session exists");
    });

    it("Should allow ending a session", async function () {
      const ipfsCID = "ipfs://session1";
      const dataHash = ethers.keccak256(ethers.toUtf8Bytes("test data"));

      // Wait for minimum session duration
      await ethers.provider.send("evm_increaseTime", [300]); // Add 5 minutes
      await ethers.provider.send("evm_mine", []);

      await sessionNFT.connect(player).endSession(ipfsCID, dataHash);
      
      const session = await sessionNFT.getSession(sessionId);
      expect(session.ipfsCID).to.equal(ipfsCID);
      expect(session.dataHash).to.equal(dataHash);
      expect(session.endTime).to.not.equal(0);
    });

    it("Should not allow ending session before minimum duration", async function () {
      const ipfsCID = "ipfs://session1";
      const dataHash = ethers.keccak256(ethers.toUtf8Bytes("test data"));

      // Try to end immediately
      await expect(
        sessionNFT.connect(player).endSession(ipfsCID, dataHash)
      ).to.be.revertedWith("Session too short");
    });

    it("Should allow publisher to verify session", async function () {
      const ipfsCID = "ipfs://session1";
      const dataHash = ethers.keccak256(ethers.toUtf8Bytes("test data"));

      // End session
      await ethers.provider.send("evm_increaseTime", [300]); // Add 5 minutes
      await ethers.provider.send("evm_mine", []);
      await sessionNFT.connect(player).endSession(ipfsCID, dataHash);

      // Create message hash
      const session = await sessionNFT.getSession(sessionId);
      const messageHash = ethers.keccak256(
        ethers.solidityPacked(
          ["address", "uint256", "uint256", "string", "bytes32"],
          [session.player, session.startTime, session.endTime, session.ipfsCID, session.dataHash]
        )
      );

      // Sign message
      const signature = await publisher.signMessage(ethers.getBytes(messageHash));

      // Verify session
      await expect(
        sessionNFT.connect(publisher).verifySession(sessionId, signature)
      ).to.emit(sessionNFT, "SessionVerified");

      const verifiedSession = await sessionNFT.getSession(sessionId);
      expect(verifiedSession.verified).to.be.true;
    });

    it("Should not allow non-publisher to verify session", async function () {
      const ipfsCID = "ipfs://session1";
      const dataHash = ethers.keccak256(ethers.toUtf8Bytes("test data"));

      // End session
      await ethers.provider.send("evm_increaseTime", [300]); // Add 5 minutes
      await sessionNFT.connect(player).endSession(ipfsCID, dataHash);

      // Create message hash
      const session = await sessionNFT.getSession(sessionId);
      const messageHash = ethers.keccak256(
        ethers.AbiCoder.defaultAbiCoder().encode(
          ["address", "uint256", "uint256", "string", "bytes32"],
          [session.player, session.startTime, session.endTime, session.ipfsCID, session.dataHash]
        )
      );

      // Sign message with wrong account
      const signature = await player.signMessage(ethers.getBytes(messageHash));

      // Try to verify session
      await expect(
        sessionNFT.verifySession(sessionId, signature)
      ).to.be.revertedWith("Only game publisher can verify");
    });
  });
});
