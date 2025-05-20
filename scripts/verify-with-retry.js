const hre = require("hardhat");

async function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

async function verifyContract(name, address, constructorArgs) {
    console.log(`\nVerifying ${name}...`);
    try {
        await hre.run("verify:verify", {
            address: address,
            constructorArguments: constructorArgs,
        });
        console.log(`${name} verified successfully!`);
        return true;
    } catch (error) {
        console.log(`Error verifying ${name}:`, error.message);
        return false;
    }
}

async function main() {
    const DID_REGISTRY_ADDRESS = "0xF943fF97916a19124C2322Fc3D876F6BD97A2272";
    const DEE_CREDENTIAL_ADDRESS = "0x0f4b069EE340EcD111C311f5d3a07e8CCcC6EF09";
    const DEPLOYER_ADDRESS = "0x05A6850D8432cA44d9c76c3686597ea928f4e678";

    // Try to verify contracts multiple times
    for (let i = 1; i <= 5; i++) {
        console.log(`\nAttempt ${i} of 5:`);
        
        // Wait longer between each attempt
        const waitTime = i * 30000; // 30s, 60s, 90s, 120s, 150s
        console.log(`Waiting ${waitTime/1000} seconds...`);
        await sleep(waitTime);

        // Try to verify DIDRegistry
        const didSuccess = await verifyContract(
            "DIDRegistry",
            DID_REGISTRY_ADDRESS,
            [DEPLOYER_ADDRESS]
        );

        if (didSuccess) {
            // If DIDRegistry verification succeeds, wait a bit and try DEECredential
            await sleep(15000); // wait 15 seconds
            await verifyContract(
                "DEECredential",
                DEE_CREDENTIAL_ADDRESS,
                [DEPLOYER_ADDRESS, DID_REGISTRY_ADDRESS]
            );
            break; // Exit if both verifications succeed
        }
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
