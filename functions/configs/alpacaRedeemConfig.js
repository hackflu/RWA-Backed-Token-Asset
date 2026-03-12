const fs = require("fs");
const { Location, ReturnType, CodeLanguage } = require("@chainlink/functions-toolkit");

const requireConfig = {
    source: fs.readFileSync("./functions/sources/alpacaBalance.js", "utf8"),
    codeLocation: Location.Inline,
    secrets: { alpacaApiKey: process.env.ALPACA_API_KEY, alpacaSecretKey: process.env.ALPACA_SECRET_KEY },
    secretsLocation: Location.DONHosted,
    args: [],
    codeLanguage: CodeLanguage.Javascript,
    expectedReturnType: ReturnType.uint256
}

module.exports = requireConfig