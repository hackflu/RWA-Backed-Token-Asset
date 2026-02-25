const {SecretManager} = require("chainlink-functions-toolkit");
const {ethers} = require("ethers");

async function uploadSecrets() {
    
}

uploadSecrets().catch((error) => {
    console.error(error);
    process.exitCode = 1;
})