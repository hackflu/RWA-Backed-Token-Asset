if (
    !secrets.alpacaApiKey || secrets.alpacaApiKey === "" ||
    !secrets.alpacaSecretKey || secrets.alpacaSecretKey === ""
) { // Check if secrets are empty strings
    throw Error("Alpaca API key and secret key must be set in the environment and provided to the Functions request.")
}

// Log secrets for debugging (remove or redact in production)
console.log("Alpaca API Key (first 5 chars):", secrets.alpacaApiKey ? secrets.alpacaApiKey.substring(0, 5) : "N/A");
console.log("Alpaca Secret Key (first 5 chars):", secrets.alpacaSecretKey ? secrets.alpacaSecretKey.substring(0, 5) : "N/A");

const alpacaRequest = Functions.makeHttpRequest({
    url: "https://paper-api.alpaca.markets/v2/account",
    headers: { // API keys should be in the 'headers' object
        'APCA-API-KEY-ID': secrets.alpacaApiKey,
        'APCA-API-SECRET-KEY': secrets.alpacaSecretKey,
    },
})

const [Response] = await Promise.all([alpacaRequest]);

// Check for errors in the API response
if (Response.error || !Response.data) { // Check for Response.error or missing data
    // Log the full response object for better debugging
    console.error("Full Alpaca API Response on error:", JSON.stringify(Response, null, 2));
    throw Error(`Alpaca API Error: ${Response.error?.message || Response.error || "Unknown API error"}. Check console for full response details.`);
}
    if (typeof Response.data.portfolio_value === 'undefined') {
    // Log the full response object for better debugging
    console.error("Full Alpaca API Response (missing portfolio_value):", JSON.stringify(Response, null, 2));
    throw Error(`Alpaca API did not return expected data. Full response: ${JSON.stringify(Response)}`);
}

const postfolioBalance = Response.data.portfolio_value;
console.log(`Portfolio Balance: ${postfolioBalance}`); // Corrected typo "Postfolio" to "Portfolio"

return Functions.encodeUint256(Math.round(postfolioBalance * 1000000000000000000))