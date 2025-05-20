const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("DEECredential", function () {
  let didRegistry;
  let credential;
  let owner;
  let addr1;
  let addr2;

  beforeEach(async function () {
    [owner, addr1, addr2] = await ethers.getSigners();
    
    // Deploy DIDRegistry first
    const DIDRegistry = await ethers.getContractFactory("DIDRegistry");
    didRegistry = await DIDRegistry.deploy(owner.address);
    await didRegistry.waitForDeployment();
    
    // Deploy DEECredential with DIDRegistry address
    const DEECredential = await ethers.getContractFactory("DEECredential");
    credential = await DEECredential.deploy(owner.address, await didRegistry.getAddress());
    await credential.waitForDeployment();
    
    // Create DID for addr1 (will be recipient)
    await didRegistry.connect(addr1).createDID("ipfs://did-document-hash");
  });
  it("Should mint a new credential", async function () {
    const tx = await credential.mintCredential(
      addr1.address,
      "ipfs://credential-hash",
      "Bachelor_Degree"
    );
    await tx.wait();
    
    const tokenId = 1;
    expect(await credential.ownerOf(tokenId)).to.equal(addr1.address);

    const credentialData = await credential.getCredential(tokenId);
    expect(credentialData[0]).to.equal("ipfs://credential-hash");
    expect(credentialData[1]).to.equal("Bachelor_Degree");
    expect(credentialData[3]).to.equal(addr1.address); // Check DID holder
  });
  it("Should not mint credential for address without DID", async function () {
    await expect(
      credential.mintCredential(
        addr2.address, // addr2 doesn't have a DID
        "ipfs://credential-hash",
        "Bachelor_Degree"
      )
    ).to.be.revertedWith("DID does not exist");
  });

  it("Should transfer credential between DID holders", async function () {
    // Mint credential to addr1
    await credential.mintCredential(addr1.address, "ipfs://credential-hash", "Bachelor_Degree");
    const tokenId = 1;
    
    // Create DID for addr2
    await didRegistry.connect(addr2).createDID("ipfs://did-document-hash-2");
    
    // Transfer from addr1 to addr2
    await credential.connect(addr1).transferCredential(addr2.address, tokenId);
    expect(await credential.ownerOf(tokenId)).to.equal(addr2.address);
    
    const credentialData = await credential.getCredential(tokenId);
    expect(credentialData[3]).to.equal(addr2.address); // Check DID holder updated
  });

  it("Should update credential metadata", async function () {
    await credential.mintCredential(addr1.address, "ipfs://testhash", "TestType");
    const tokenId = 1;
    
    await credential.updateCredentialMetadata(tokenId, "ipfs://newhash", "NewType");
    const credentialData = await credential.getCredential(tokenId);
    expect(credentialData[0]).to.equal("ipfs://newhash");
    expect(credentialData[1]).to.equal("NewType");
  });

  it("Should set base URI", async function () {
    const baseURI = "https://api.example.com/token/";
    await credential.setBaseURI(baseURI);
    
    await credential.mintCredential(addr1.address, "ipfs://testhash", "TestType");
    const tokenId = 1;
    
    expect(await credential.tokenURI(tokenId)).to.equal(baseURI + tokenId);
  });  it("Should fail when non-owner tries to mint", async function () {
    await expect(
      credential.connect(addr1).mintCredential(addr2.address, "ipfs://testhash", "TestType")
    ).to.be.revertedWithCustomError(credential, "OwnableUnauthorizedAccount")
      .withArgs(addr1.address);
  });

  it("Should fail when non-owner tries to update metadata", async function () {
    await credential.mintCredential(addr1.address, "ipfs://testhash", "TestType");
    const tokenId = 1;

    await expect(
      credential.connect(addr1).updateCredentialMetadata(tokenId, "ipfs://newhash", "NewType")
    ).to.be.revertedWithCustomError(credential, "OwnableUnauthorizedAccount")
      .withArgs(addr1.address);
  });

  it("Should fail when trying to get non-existent credential", async function () {
    await expect(
      credential.getCredential(999)
    ).to.be.revertedWith("Credential does not exist");
  });
});
