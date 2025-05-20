const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("DIDRegistry Advanced Tests", function () {
  let didRegistry;
  let owner;
  let issuer;
  let user1;
  let user2;
  
  beforeEach(async function () {
    [owner, issuer, user1, user2] = await ethers.getSigners();
    
    const DIDRegistry = await ethers.getContractFactory("DIDRegistry");
    didRegistry = await DIDRegistry.deploy(owner.address);
    await didRegistry.deployed();
    
    // Grant ISSUER_ROLE to issuer
    const ISSUER_ROLE = await didRegistry.ISSUER_ROLE();
    await didRegistry.grantRole(ISSUER_ROLE, issuer.address);
    
    // Unpause the contract
    await didRegistry.unpause();
  });

  describe("Emergency Scenarios", function () {
    it("should handle emergency stop correctly", async function () {
      // Create DID before emergency
      await didRegistry.connect(user1).createDID("QmTest1");
      
      // Emergency stop
      await didRegistry.emergencyStop();
      
      // Try operations during emergency
      await expect(
        didRegistry.connect(user2).createDID("QmTest2")
      ).to.be.revertedWith("Pausable: paused");
      
      // Resume operations
      await didRegistry.emergencyResume();
      
      // Should work after resume
      await didRegistry.connect(user2).createDID("QmTest2");
    });
  });

  describe("Rate Limiting", function () {
    it("should enforce rate limits", async function () {
      // First operation should succeed
      await didRegistry.connect(user1).createDID("QmTest1");
      
      // Second immediate operation should fail
      await expect(
        didRegistry.connect(user1).createDID("QmTest2")
      ).to.be.revertedWith("Rate limit exceeded");
      
      // Wait for rate limit
      await ethers.provider.send("evm_increaseTime", [61]);
      await ethers.provider.send("evm_mine");
      
      // Should work after waiting
      await didRegistry.connect(user1).createDID("QmTest2");
    });
  });

  describe("Batch Operations", function () {
    it("should handle batch DID creation correctly", async function () {
      const addresses = [user1.address, user2.address];
      const ipfsHashes = ["QmTest1", "QmTest2"];
      
      await didRegistry.connect(owner).batchCreateDIDs(addresses, ipfsHashes);
      
      // Verify DIDs were created
      const did1 = await didRegistry.resolveDID(user1.address);
      const did2 = await didRegistry.resolveDID(user2.address);
      
      expect(did1.ipfsHash).to.equal("QmTest1");
      expect(did2.ipfsHash).to.equal("QmTest2");
    });
  });

  describe("DID Resolution", function () {
    it("should handle invalid DID resolution gracefully", async function () {
      await expect(
        didRegistry.resolveDID(ethers.constants.AddressZero)
      ).to.be.revertedWith("DID does not exist");
    });
  });

  describe("Access Control", function () {
    it("should enforce role-based access control", async function () {
      // Try to add issuer without admin role
      await expect(
        didRegistry.connect(user1).addIssuer(user2.address)
      ).to.be.revertedWith("AccessControl:");
      
      // Try to issue credential without issuer role
      await expect(
        didRegistry.connect(user1).issueCredential(user2.address, "QmTest", "TestType")
      ).to.be.revertedWith("AccessControl:");
    });
  });
});
