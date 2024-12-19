const fs = require("fs");
const path = require("path");
const { ethers, run } = require("hardhat");

const DEPLOYMENT_DIR = path.join(__dirname, "../../deployments");

async function writeDeploymentData(data) {
    if (!fs.existsSync(DEPLOYMENT_DIR)) {
        fs.mkdirSync(DEPLOYMENT_DIR, { recursive: true });
    }
    
    const filename = `${data.network}_${data.timestamp.split('T')[0]}.json`;
    const filepath = path.join(DEPLOYMENT_DIR, filename);
    
    fs.writeFileSync(
        filepath,
        JSON.stringify(data, null, 2)
    );
    
    console.log(`Deployment data saved to: ${filepath}`);
}

async function readDeploymentData(network = "") {
    if (!network) {
        network = (await ethers.provider.getNetwork()).name;
    }
    
    const files = fs.readdirSync(DEPLOYMENT_DIR);
    const deploymentFiles = files.filter(f => f.startsWith(network));
    
    if (deploymentFiles.length === 0) {
        throw new Error(`No deployment found for network: ${network}`);
    }
    
    // Get the most recent deployment
    const latestFile = deploymentFiles
        .sort((a, b) => b.localeCompare(a))[0];
    
    const filepath = path.join(DEPLOYMENT_DIR, latestFile);
    return JSON.parse(fs.readFileSync(filepath, 'utf8'));
}

async function verifyContract(address, constructorArguments) {
    try {
        await run("verify:verify", {
            address: address,
            constructorArguments: constructorArguments,
        });
        console.log(`Contract at ${address} verified successfully`);
    } catch (error) {
        console.log(`Error verifying contract at ${address}:`, error.message);
    }
}

module.exports = {
    writeDeploymentData,
    readDeploymentData,
    verifyContract
};
