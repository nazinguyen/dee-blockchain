const hre = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  // Deploy DIDRegistry first
  console.log("Deploying DIDRegistry...");
  const DIDRegistry = await ethers.getContractFactory("DIDRegistry");
  const didRegistry = await DIDRegistry.deploy(deployer.address);
  await didRegistry.waitForDeployment();
  const didRegistryAddress = await didRegistry.getAddress();
  console.log("DIDRegistry deployed to:", didRegistryAddress);

  // Deploy DEECredential with DIDRegistry address
  console.log("Deploying DEECredential...");
  const DEECredential = await ethers.getContractFactory("DEECredential");
  const deeCredential = await DEECredential.deploy(deployer.address, didRegistryAddress);
  await deeCredential.waitForDeployment();
  const credentialAddress = await deeCredential.getAddress();
  console.log("DEECredential deployed to:", credentialAddress);

  // Wait for block confirmations
  console.log("Waiting for block confirmations...");
  await deeCredential.deploymentTransaction().wait(6);

  // Verify DIDRegistry
  console.log("Verifying DIDRegistry...");
  try {
    await hre.run("verify:verify", {
      address: didRegistryAddress,
      constructorArguments: [deployer.address],
    });
    console.log("DIDRegistry verified successfully");
  } catch (error) {
    console.log("Error verifying DIDRegistry:", error);
  }

  // Verify DEECredential
  console.log("Verifying DEECredential...");
  try {
    await hre.run("verify:verify", {
      address: credentialAddress,
      constructorArguments: [deployer.address, didRegistryAddress],
    });
    console.log("DEECredential verified successfully");
  } catch (error) {
    console.log("Error verifying DEECredential:", error);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
