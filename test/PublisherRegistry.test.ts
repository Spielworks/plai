import { expect } from "chai";
import { ethers } from "hardhat";
import { PublisherRegistry } from "../typechain-types";
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";

describe("PublisherRegistry", function () {
  let publisherRegistry: PublisherRegistry;
  let owner: SignerWithAddress;
  let publisher: SignerWithAddress;
  let otherAccount: SignerWithAddress;

  beforeEach(async function () {
    [owner, publisher, otherAccount] = await ethers.getSigners();
    
    const PublisherRegistry = await ethers.getContractFactory("PublisherRegistry");
    publisherRegistry = await PublisherRegistry.deploy(owner.address);
  });

  describe("Publisher Verification", function () {
    it("Should allow owner to verify a publisher", async function () {
      await publisherRegistry.verifyPublisher(
        publisher.address,
        "Test Publisher",
        "https://test-publisher.com"
      );

      const isVerified = await publisherRegistry.isVerifiedPublisher(publisher.address);
      expect(isVerified).to.be.true;
    });

    it("Should not allow non-owner to verify a publisher", async function () {
      await expect(
        publisherRegistry.connect(otherAccount).verifyPublisher(
          publisher.address,
          "Test Publisher",
          "https://test-publisher.com"
        )
      ).to.be.reverted;
    });

    it("Should not allow verifying the same publisher twice", async function () {
      await publisherRegistry.verifyPublisher(
        publisher.address,
        "Test Publisher",
        "https://test-publisher.com"
      );

      await expect(
        publisherRegistry.verifyPublisher(
          publisher.address,
          "Test Publisher 2",
          "https://test-publisher2.com"
        )
      ).to.be.revertedWith("Publisher already exists");
    });
  });

  describe("Publisher Management", function () {
    beforeEach(async function () {
      await publisherRegistry.verifyPublisher(
        publisher.address,
        "Test Publisher",
        "https://test-publisher.com"
      );
    });

    it("Should allow owner to deactivate a publisher", async function () {
      await publisherRegistry.deactivatePublisher(publisher.address);
      const isVerified = await publisherRegistry.isVerifiedPublisher(publisher.address);
      expect(isVerified).to.be.false;
    });

    it("Should allow owner to reactivate a publisher", async function () {
      await publisherRegistry.deactivatePublisher(publisher.address);
      await publisherRegistry.reactivatePublisher(publisher.address);
      const isVerified = await publisherRegistry.isVerifiedPublisher(publisher.address);
      expect(isVerified).to.be.true;
    });

    it("Should return correct publisher details", async function () {
      const publisherData = await publisherRegistry.getPublisher(publisher.address);
      expect(publisherData.name).to.equal("Test Publisher");
      expect(publisherData.website).to.equal("https://test-publisher.com");
      expect(publisherData.active).to.be.true;
    });
  });
});
