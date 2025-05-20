const hre = require("hardhat");

async function waitForConfirmations(tx, confirmations = 6) {
    console.log(`Waiting for ${confirmations} confirmations...`);
    const receipt = await tx.wait(confirmations);
    return receipt;
}

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address);
    console.log("Account balance:", (await deployer.provider.getBalance(deployer.address)).toString());

    // Deploy DIDRegistry
    console.log("\nDeploying DIDRegistry...");
    const DIDRegistry = await ethers.getContractFactory("DIDRegistry");
    const didRegistry = await DIDRegistry.deploy(deployer.address);
    await waitForConfirmations(didRegistry.deploymentTransaction());
    const didRegistryAddress = await didRegistry.getAddress();
    console.log("DIDRegistry deployed to:", didRegistryAddress);

    // Deploy DEECredential
    console.log("\nDeploying DEECredential...");
    const DEECredential = await ethers.getContractFactory("DEECredential");
    const deeCredential = await DEECredential.deploy(deployer.address, didRegistryAddress);
    await waitForConfirmations(deeCredential.deploymentTransaction());
    const credentialAddress = await deeCredential.getAddress();
    console.log("DEECredential deployed to:", credentialAddress);

    // Wait additional time for blockchain indexer
    console.log("\nWaiting additional time for blockchain indexer...");
    await new Promise(resolve => setTimeout(resolve, 60000)); // wait 60 seconds

    // Verify DIDRegistry
    console.log("\nVerifying DIDRegistry...");
    try {
        await hre.run("verify:verify", {
            address: didRegistryAddress,
            constructorArguments: [deployer.address],
        });
        console.log("DIDRegistry verified successfully");
    } catch (error) {
        console.error("Error verifying DIDRegistry:", error);
    }

    // Wait between verifications
    await new Promise(resolve => setTimeout(resolve, 30000)); // wait 30 seconds

    // Verify DEECredential
    console.log("\nVerifying DEECredential...");
    try {
        await hre.run("verify:verify", {
            address: credentialAddress,
            constructorArguments: [deployer.address, didRegistryAddress],
        });
        console.log("DEECredential verified successfully");
    } catch (error) {
        console.error("Error verifying DEECredential:", error);
    }

    // Log final addresses
    console.log("\nDeployment Summary:");
    console.log("DIDRegistry:", didRegistryAddress);
    console.log("DEECredential:", credentialAddress);
    console.log("\nSave these addresses for future reference!");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
