// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/// @title dTSLA
/// @author hackflu
contract dTSLA is FunctionsClient, ConfirmedOwner, ERC20 {
    /*//////////////////////////////////////////////////////////////
                            TYPE DECLERATION
    //////////////////////////////////////////////////////////////*/
    using FunctionsRequest for FunctionsRequest.Request;

    enum MinOrRedeem {
        Mint,
        redeem
    }

    struct dTeslaRequest {
        uint256 amountOfToken;
        address requester;
        MinOrRedeem mintOrRedeem;
    }
    /*//////////////////////////////////////////////////////////////
                                  ERROR
    //////////////////////////////////////////////////////////////*/
    error dTSLA_NotEngoughCollateral();

    /*//////////////////////////////////////////////////////////////
                             STATE VARIABLE
    //////////////////////////////////////////////////////////////*/
    string private s_mintSourceCode;
    mapping(bytes32 requestId => dTeslaRequest request) private s_requestId;
    address constant SEPLOIA_FUNCTIONS_ROUTER = 0xb83E47C2bC239B3bf370bc41e1459A34b41238D0;
    // for now we are using the LINK/USD
    address constant SEPLOIA_TSLA_FEED = 0xc59E3633BAAC79493d908e63626716e204A45EdF;
    // USDC/USD feed
    address constant SEPOLIA_USDC_FEED = 0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E;
    bytes32 constant DON_ID = hex"66756e2d657468657265756d2d7365706f6c69612d3100000000000000000000";
    uint32 constant GAS_LIMIT = 300_000;
    uint256 constant PRECISION = 1e18;
    uint256 constant TSLA_PRICE_DECIMAL_PRECISION = 1e10;
    uint256 constant COLLATERAL_RATIO = 200;
    uint256 constant COLLATERAL_PRECESION = 100;
    uint256 constant MINNIMUM_WITHDRWAL_AMOUNT = 100e18;
    uint64 immutable i_subscriptionId;
    uint256 private s_portfolioBalance;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(uint64 subscriptionId, address router)
        FunctionsClient(router)
        ConfirmedOwner(msg.sender)
        ERC20("dTSLA", "dTSLA")
    {
        i_subscriptionId = subscriptionId;
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTION
    //////////////////////////////////////////////////////////////*/
    /// Send an HTTP request to:
    /// 1. See how much TSLA is bought
    /// 2. If enough TSLA is in the alpace account.
    /// mint dTSLA
    function sendMintRequest(uint256 amount) external onlyOwner returns (bytes32) {
        FunctionsRequest.Request memory request;
        request.initializeRequestForInlineJavaScript(s_mintSourceCode);
        bytes32 requestId = _sendRequest(request.encodeCBOR(), i_subscriptionId, GAS_LIMIT, DON_ID);
        s_requestId[requestId].amountOfToken = amount;
        s_requestId[requestId].requester = msg.sender;
        s_requestId[requestId].mintOrRedeem = MinOrRedeem.Mint;
        return requestId;
    }

    /// @notice User Sends a request to sell TSLA for USDC (redeemption Token)
    /// This will , have the chainlink function call our aplace (bank)
    /// and do the following
    /// 1. Sel TSLA  on the brokerage
    /// 2. Buy the USDC on the brokerage
    /// 3. Send the USDC to this contract for the user to withdraw
    function sendRedeemRequest(uint256 amountdTsla) external {
        uint256 amountTslaInUsdc = getUsdcValueOfUsd(getUsdValueOfTsla(amountdTsla));
    }

    function fulfillRequest(
        bytes32 requestId,
        bytes memory response,
        bytes memory /*err*/
    )
        internal
        virtual
        override
    {
        if (s_requestId[requestId].mintOrRedeem == MinOrRedeem.Mint) {
            _mintFulFilRequest(requestId, response);
        } else {
            _redeemFulFilRequest();
        }
    }

    function getCalculatedNewTokenValue(uint256 amountOfTokenToMint) public view returns (uint256) {
        return ((totalSupply() + amountOfTokenToMint) * getTslaPrice()) / PRECISION;
    }

    function getUsdcValueOfUsd(uint256 amount) public view returns (uint256) {
        return (amount * getUsdcPrice()) / PRECISION;
    }

    function getUsdValueOfTsla(uint256 tslAmount) public view returns (uint256) {
        return (tslAmount * getTslaPrice()) / PRECISION;
    }

    //// return the TSLA price in USDC
    function getTslaPrice() public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(SEPLOIA_TSLA_FEED);
        (, int256 priceOfTslaInUSDC,,,) = priceFeed.latestRoundData();
        return uint256(priceOfTslaInUSDC) * TSLA_PRICE_DECIMAL_PRECISION;
    }

    //// return the USDC price in USDC
    function getUsdcPrice() public view returns (uint256) {
        {
            AggregatorV3Interface priceFeed = AggregatorV3Interface(SEPOLIA_USDC_FEED);
            (, int256 priceOfTslaInUSDC,,,) = priceFeed.latestRoundData();
            return uint256(priceOfTslaInUSDC) * TSLA_PRICE_DECIMAL_PRECISION;
        }
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTION
    //////////////////////////////////////////////////////////////*/

    /// Return the amount of TSLA value in USD is stored in our broker
    /// If we have enough TSAL token mint the dTSLA
    function _mintFulFilRequest(bytes32 requestId, bytes memory response) internal {
        uint256 amountOfTokenToMint = s_requestId[requestId].amountOfToken;
        // this portfoilio Balance will be in USDC
        s_portfolioBalance = uint256(bytes32(response));
        if (_getCollateralRatioAdjustTotalBalance(amountOfTokenToMint) > s_portfolioBalance) {
            revert dTSLA_NotEngoughCollateral();
        }
        if (amountOfTokenToMint > 0) {
            _mint(s_requestId[requestId].requester, amountOfTokenToMint);
        }
    }

    function _redeemFulFilRequest() internal {}

    /// this function convert the minted
    function _getCollateralRatioAdjustTotalBalance(uint256 amountOfToken) internal view returns (uint256) {
        uint256 calaculatedNewTokenValue = getCalculatedNewTokenValue(amountOfToken);
        return (calaculatedNewTokenValue * COLLATERAL_RATIO) / COLLATERAL_PRECESION;
    }
}
