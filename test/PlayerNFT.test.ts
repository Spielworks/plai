import { expect } from "chai";
import { ethers } from "hardhat";
import { PlayerNFT } from "../typechain-types";
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";

describe("PlayerNFT", function () {
  let playerNFT: PlayerNFT;
  let owner: SignerWithAddress;
  let player1: SignerWithAddress;
  let player2: SignerWithAddress;

  beforeEach(async function () {
    [owner, player1, player2] = await ethers.getSigners();
    
    const PlayerNFT = await ethers.getContractFactory("PlayerNFT");
    playerNFT = await PlayerNFT.deploy(owner.address);
  });

  describe("Player NFT Management", function () {
    it("Should allow a player to mint their NFT", async function () {
      await playerNFT.safeMint(player1.address, "ipfs://player1");
      
      expect(await playerNFT.hasPlayerNFT(player1.address)).to.be.true;
      expect(await playerNFT.getPlayerTokenId(player1.address)).to.equal(1);
    });

    it("Should not allow a player to mint multiple NFTs", async function () {
      await playerNFT.safeMint(player1.address, "ipfs://player1");
      
      await expect(
        playerNFT.safeMint(player1.address, "ipfs://player1-second")
      ).to.be.revertedWith("Player already has an NFT");
    });

    it("Should return correct token URI", async function () {
      await playerNFT.safeMint(player1.address, "ipfs://player1");
      const tokenId = await playerNFT.getPlayerTokenId(player1.address);
      
      expect(await playerNFT.tokenURI(tokenId)).to.equal("ipfs://player1");
    });

    it("Should correctly check if player has NFT", async function () {
      expect(await playerNFT.hasPlayerNFT(player1.address)).to.be.false;
      
      await playerNFT.safeMint(player1.address, "ipfs://player1");
      expect(await playerNFT.hasPlayerNFT(player1.address)).to.be.true;
    });

    it("Should revert when getting token ID for player without NFT", async function () {
      await expect(
        playerNFT.getPlayerTokenId(player1.address)
      ).to.be.revertedWith("Player does not have an NFT");
    });
  });
});
