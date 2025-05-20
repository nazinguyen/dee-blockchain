const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("DIDRegistry", function () {
  let DIDRegistry;
  let didRegistry;
  let owner;
  let user1;
  let user2;

  beforeEach(async function () {
    [owner, user1, user2] = await ethers.getSigners();
    DIDRegistry = await ethers.getContractFactory("DIDRegistry");
    didRegistry = await DIDRegistry.deploy(owner.address);
    await didRegistry.waitForDeployment();
  });

  describe("DID Management", function () {
    const ipfsHash = "QmTest123";
    const newIpfsHash = "QmTest456";

    it("Should create a new DID", async function () {
      const tx = await didRegistry.connect(user1).createDID(ipfsHash);
      const receipt = await tx.wait();
      
      const didEvent = receipt.logs.find(
        (event) => event.eventName === "DIDCreated"
      );
      expect(didEvent).to.not.be.undefined;

      const [storedHash, , active] = await didRegistry.resolveDID(user1.address);
      expect(storedHash).to.equal(ipfsHash);
      expect(active).to.be.true;
    });

    it("Should not allow creating duplicate DID", async function () {
      await didRegistry.connect(user1).createDID(ipfsHash);
      await expect(
        didRegistry.connect(user1).createDID(ipfsHash)
      ).to.be.revertedWith("DID already exists");
    });

    it("Should update DID document", async function () {
      await didRegistry.connect(user1).createDID(ipfsHash);
      await didRegistry.connect(user1).updateDID(newIpfsHash);

      const [storedHash] = await didRegistry.resolveDID(user1.address);
      expect(storedHash).to.equal(newIpfsHash);
    });

    it("Should deactivate DID", async function () {
      await didRegistry.connect(user1).createDID(ipfsHash);
      await didRegistry.connect(user1).deactivateDID();

      const [, , active] = await didRegistry.resolveDID(user1.address);
      expect(active).to.be.false;
    });
  });

  describe("Delegate Management", function () {
    const ipfsHash = "QmTest123";
    const delegate = "delegate1";

    beforeEach(async function () {
      await didRegistry.connect(user1).createDID(ipfsHash);
    });

    it("Should add delegate", async function () {
      await didRegistry.connect(user1).addDelegate(delegate);
      expect(await didRegistry.isDelegate(user1.address, delegate)).to.be.true;
    });

    it("Should remove delegate", async function () {
      await didRegistry.connect(user1).addDelegate(delegate);
      await didRegistry.connect(user1).removeDelegate(delegate);
      expect(await didRegistry.isDelegate(user1.address, delegate)).to.be.false;
    });
  });
});
