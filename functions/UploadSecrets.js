require("dotenv").config();
const { SecretsManager, simulateScript } = require("@chainlink/functions-toolkit");
const { ethers } = require("ethers");
async function uploadSecrets() {
    const routerAddress = "0xb83E47C2bC239B3bf370bc41e1459A34b41238D0"
    const donId = "fun-ethereum-sepolia-1"
    const gatewayUrls = [
        "https://01.functions-gateway.testnet.chain.link/",
        "https://02.functions-gateway.testnet.chain.link/"
    ]
    //// never do this for the production
    //// encrypt it ......
    const privateKey = process.env.PRIVATE_KEY;
    const rpcUrl = process.env.SEPOLIA_RPC_URL;
    const secrets = { alpacaApiKey: process.env.ALPACA_API_KEY, alpacaSecretKey: process.env.ALPACA_SECRET_KEY }

    const provider = new ethers.providers.JsonRpcProvider(rpcUrl);
    const wallet = new ethers.Wallet(privateKey, provider);
    const signer = wallet.connect(provider);
    console.log("Signer address:", await signer.getAddress());
    /// encrypt the secrets before uploading
    const secretsManager = new SecretsManager({
        signer,
        functionsRouterAddress: routerAddress,
        donId: donId
    })

    await secretsManager.initialize();
    const keys = await secretsManager.fetchKeys()
    console.log("full keys object:", JSON.stringify(keys)) // log the whole object
    console.log("public key after Sending the request", keys.publicKey)
    const encryptedSecrets = await secretsManager.encryptSecrets(secrets);
    console.log("encryptedSecrets object:", JSON.stringify(encryptedSecrets))
    const soltIdNumber = 0

    const expirationTimeMinute = 1440

    const uploadResult = await secretsManager.uploadEncryptedSecretsToDON({
        encryptedSecretsHexstring: encryptedSecrets.encryptedSecrets,
        gatewayUrls: gatewayUrls,
        slotId: soltIdNumber,
        minutesUntilExpiration: expirationTimeMinute,
        subscriptionId: 6299
    })

    if (!uploadResult.success) {
        throw Error(`Failed : Encrypted secrets not uploaded to ${gatewayUrls}`)
    }
    console.log(`\n✅ Encrypted secrets uploaded to ${gatewayUrls}`)
    const donHostedSecretsVersion = parseInt(uploadResult.version)
    console.log(`Secrets version : ${donHostedSecretsVersion}`)
}

uploadSecrets().catch((error) => {
    console.error(error);
    process.exitCode = 1;
})