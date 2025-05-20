const hre = require("hardhat");

async function main() {
    const DID_REGISTRY_ADDRESS = "0xF943fF97916a19124C2322Fc3D876F6BD97A2272";
    const DEE_CREDENTIAL_ADDRESS = "0x0f4b069EE340EcD111C311f5d3a07e8CCcC6EF09";
    const DEPLOYER_ADDRESS = "0x05A6850D8432cA44d9c76c3686597ea928f4e678";

    console.log("Waiting 30 seconds before verification...");
    await new Promise(resolve => setTimeout(resolve, 30000)); // wait 30 seconds

    console.log("Verifying DIDRegistry...");
    try {
        await hre.run("verify:verify", {
            address: DID_REGISTRY_ADDRESS,
            constructorArguments: [DEPLOYER_ADDRESS],
        });
        console.log("DIDRegistry verified successfully!");
    } catch (error) {
        console.error("Error verifying DIDRegistry:", error);
    }

    console.log("\nWaiting 10 seconds before next verification...");
    await new Promise(resolve => setTimeout(resolve, 10000)); // wait 10 seconds

    console.log("Verifying DEECredential...");
    try {
        await hre.run("verify:verify", {
            address: DEE_CREDENTIAL_ADDRESS,
            constructorArguments: [DEPLOYER_ADDRESS, DID_REGISTRY_ADDRESS],
        });
        console.log("DEECredential verified successfully!");
    } catch (error) {
        console.error("Error verifying DEECredential:", error);
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
