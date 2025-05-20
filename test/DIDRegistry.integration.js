const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("DIDRegistry Integration", function () {
    let didRegistry;
    let owner;
    let admin;
    let user1;
    const ADMIN_ROLE = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("ADMIN_ROLE"));

    beforeEach(async function () {
        [owner, admin, user1] = await ethers.getSigners();
        const DIDRegistry = await ethers.getContractFactory("DIDRegistry");
        didRegistry = await DIDRegistry.deploy(owner.address);
        await didRegistry.waitForDeployment();

        // Grant admin role
        await didRegistry.grantRole(ADMIN_ROLE, admin.address);
    });

    describe("IPFS Integration", function () {
        it("Should validate IPFS hash format", async function () {
            // Valid IPFS hash starts with "Qm" and is 46 chars long
            const validHash = "QmPK1s3pNYLi9ERiq3BDxKa4XosgWwFRQUydHUtz4YgpqB";
            const invalidHash = "invalid-hash";

            expect(await didRegistry.validateIPFSHash(validHash)).to.be.true;
            expect(await didRegistry.validateIPFSHash(invalidHash)).to.be.false;
        });

        it("Should emit metadata events on DID operations", async function () {
            const ipfsHash = "QmPK1s3pNYLi9ERiq3BDxKa4XosgWwFRQUydHUtz4YgpqB";
            const did = `did:dee:${user1.address.toLowerCase()}`;

            // Create DID
            await expect(didRegistry.connect(user1).createDID(ipfsHash))
                .to.emit(didRegistry, "MetadataAdded")
                .withArgs(did, ipfsHash, await ethers.provider.getBlock("latest").then(b => b.timestamp));
        });
    });

    describe("Frontend Integration", function () {
        it("Should return paginated DID list", async function () {
            // Create multiple DIDs
            const users = [user1, admin];
            const ipfsHash = "QmPK1s3pNYLi9ERiq3BDxKa4XosgWwFRQUydHUtz4YgpqB";
            
            for(const user of users) {
                await didRegistry.connect(user).createDID(ipfsHash);
            }

            const dids = await didRegistry.getDIDs(0, 10);
            expect(dids.length).to.equal(2);
            expect(dids[0].active).to.be.true;
        });
    });

    describe("Backend Integration", function () {
        it("Should perform batch DID creation", async function () {
            const ipfsHashes = [
                "QmPK1s3pNYLi9ERiq3BDxKa4XosgWwFRQUydHUtz4YgpqB",
                "QmPK1s3pNYLi9ERiq3BDxKa4XosgWwFRQUydHUtz4YgpqC"
            ];
            const identities = [user1.address, admin.address];

            await didRegistry.connect(admin).batchCreateDIDs(identities, ipfsHashes);

            // Verify DIDs were created
            const [hash1] = await didRegistry.resolveDID(user1.address);
            const [hash2] = await didRegistry.resolveDID(admin.address);
            
            expect(hash1).to.equal(ipfsHashes[0]);
            expect(hash2).to.equal(ipfsHashes[1]);
        });

        it("Should enforce rate limiting", async function () {
            const ipfsHash = "QmPK1s3pNYLi9ERiq3BDxKa4XosgWwFRQUydHUtz4YgpqB";
            
            // First request should succeed
            await didRegistry.connect(user1).createDID(ipfsHash);

            // Second request should fail due to rate limit
            await expect(
                didRegistry.connect(user1).updateDID(ipfsHash)
            ).to.be.revertedWith("Rate limit exceeded");
        });

        it("Should track contract statistics", async function () {
            const ipfsHash = "QmPK1s3pNYLi9ERiq3BDxKa4XosgWwFRQUydHUtz4YgpqB";
            
            // Create a DID
            await didRegistry.connect(user1).createDID(ipfsHash);
            
            const stats = await didRegistry.getContractStats();
            expect(stats[0]).to.equal(1); // totalDIDs
            expect(stats[1]).to.equal(1); // activeDIDs
            
            // Deactivate DID
            await didRegistry.connect(user1).deactivateDID();
            
            const newStats = await didRegistry.getContractStats();
            expect(newStats[1]).to.equal(0); // activeDIDs should decrease
        });
    });
});
