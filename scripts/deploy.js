const hre = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  const DEECredential = await ethers.getContractFactory("DEECredential");
  const deeCredential = await DEECredential.deploy(deployer.address);
  
  // Wait for the deployment transaction to be mined
  const deployedContract = await deeCredential.waitForDeployment();
  const contractAddress = await deployedContract.getAddress();

  console.log("DEECredential deployed to:", contractAddress);

  // Verify the contract on Polygonscan
  console.log("Waiting for block confirmations...");
  await deeCredential.deploymentTransaction().wait(6); // wait for 6 block confirmations

  // Verify the contract
  try {
    await hre.run("verify:verify", {
      address: contractAddress,
      constructorArguments: [deployer.address],
    });
    console.log("Contract verified successfully");
  } catch (error) {
    console.log("Error verifying contract:", error);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
