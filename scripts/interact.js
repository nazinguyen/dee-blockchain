const hre = require("hardhat");

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("Interacting with contracts using account:", deployer.address);    // Get contract instances    const didRegistry = await ethers.getContractAt("DIDRegistry", "0xF943fF97916a19124C2322Fc3D876F6BD97A2272");
    const deeCredential = await ethers.getContractAt("DEECredential", "0x0f4b069EE340EcD111C311f5d3a07e8CCcC6EF09");// Check if DID exists first
    try {
        console.log("Checking existing DID...");
        const [existingHash, existingUpdated, existingActive] = await didRegistry.resolveDID(deployer.address);
        console.log("DID already exists!");
    } catch (error) {
        // If DID doesn't exist, create it
        console.log("No existing DID found. Creating new DID...");
        const ipfsHash = "QmExample"; // Replace with actual IPFS hash
        const createDIDTx = await didRegistry.createDID(ipfsHash);
        await createDIDTx.wait();
        console.log("DID created!");
    }// Get DID details
    const [hash, updated, active] = await didRegistry.resolveDID(deployer.address);
    console.log("DID Details:");
    console.log("- IPFS Hash:", hash);
    console.log("- Last Updated:", new Date(Number(updated) * 1000).toLocaleString());
    console.log("- Active:", active);

    // Mint a credential
    console.log("\nMinting credential...");
    const credentialHash = "QmCredential"; // Replace with actual credential IPFS hash
    const mintTx = await deeCredential.mintCredential(
        deployer.address,
        credentialHash,
        "Bachelor_Degree"
    );
    const receipt = await mintTx.wait();
    
    // Get credential ID from event
    const event = receipt.logs.find(
        (log) => log.fragment && log.fragment.name === 'CredentialMinted'
    );
    const tokenId = event.args[0];
      // Get credential details
    const [credHash, credType, issueDate, holder] = await deeCredential.getCredential(tokenId);
    console.log("\nCredential Details:");
    console.log("- Token ID:", tokenId.toString());
    console.log("- IPFS Hash:", credHash);
    console.log("- Type:", credType);
    console.log("- Issue Date:", new Date(Number(issueDate) * 1000).toLocaleString());
    console.log("- Holder:", holder);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
