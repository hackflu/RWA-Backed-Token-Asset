// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

/// @title dTSLA
/// @author hackflu
contract dTSLA is FunctionsClient, ConfirmedOwner, ERC20 {
    /*//////////////////////////////////////////////////////////////
                            TYPE DECLERATION
    //////////////////////////////////////////////////////////////*/
    using FunctionsRequest for FunctionsRequest.Request;
    using Strings for uint256;

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
    error dTSLA_DosentMeetMinimumWithdrawalAmount();
    error dTSLA_TransactionFailed();

    /*//////////////////////////////////////////////////////////////
                             STATE VARIABLE
    //////////////////////////////////////////////////////////////*/
    string private s_mintSourceCode;
    string private s_redeemSourceCode;
    mapping(bytes32 requestId => dTeslaRequest request) private s_requestId;
    mapping(address user => uint256 pendingWithdrawalAmount) private s_userToWithdrawlAmount;
    bytes32 private s_mostRecentRequestId;
    uint8 s_donHostedSecretsSlotID = 0;
    uint64 s_donHostedSecretsVersion = 1772194071;
    uint64 immutable i_subscriptionId;
    uint256 private s_portfolioBalance;
    address immutable i_teslaUSD;
    address immutable i_usdcUSD;
    address immutable i_tokenOnSepolia;
    bytes32 immutable i_donId;
    uint32 immutable i_gasLimit;
    uint256 immutable i_precision;
    uint256 immutable i_tsla_price_decimal_precision;
    uint256 immutable i_collateral_ratio;
    uint256 immutable i_collateral_precesion;
    uint256 immutable i_minnimum_withdrwal_amount;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event dTSLA__sendMintRequested(uint256 amount);

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(
        uint64 subscriptionId,
        address router,
        string memory mintSourceCodem,
        string memory redeemSourceCode,
        address teslaUSD,
        address usdcUSD,
        address tokenOnSepolia,
        bytes32 donId,
        uint32 gas_limit,
        uint256 precision,
        uint256 tsla_price_decimal_precision,
        uint256 collateral_ratio,
        uint256 collateral_precesion,
        uint256 minnimum_withdrwal_amount
    ) FunctionsClient(router) ConfirmedOwner(msg.sender) ERC20("dTSLA", "dTSLA") {
        i_subscriptionId = subscriptionId;
        i_teslaUSD = teslaUSD;
        i_usdcUSD = usdcUSD;
        i_tokenOnSepolia = tokenOnSepolia;
        i_donId = donId;
        i_gasLimit = gas_limit;
        i_precision = precision;
        i_tsla_price_decimal_precision = tsla_price_decimal_precision;
        i_collateral_ratio = collateral_ratio;
        i_collateral_precesion = collateral_precesion;
        i_minnimum_withdrwal_amount = minnimum_withdrwal_amount;
        s_mintSourceCode = mintSourceCodem;
        s_redeemSourceCode = redeemSourceCode;
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
        request.addDONHostedSecrets(s_donHostedSecretsSlotID, s_donHostedSecretsVersion);
        bytes32 requestId = _sendRequest(request.encodeCBOR(), i_subscriptionId, i_gasLimit, i_donId);
        s_mostRecentRequestId = requestId;
        s_requestId[requestId].amountOfToken = amount;
        s_requestId[requestId].requester = msg.sender;
        s_requestId[requestId].mintOrRedeem = MinOrRedeem.Mint;
        emit dTSLA__sendMintRequested(amount);
        return requestId;
    }

    /// @notice User Sends a request to sell TSLA for USDC (redeemption Token)
    /// This will , have the chainlink function call our aplace (bank)
    /// and do the following
    /// 1. Sel TSLA  on the brokerage
    /// 2. Buy the USDC on the brokerage
    /// 3. Send the USDC to this contract for the user to withdraw
    function sendRedeemRequest(uint256 amountdTsla) external {
        /// over here we converting the usd value from the getUsdValueOfTsla as USDC
        /// and then the value is converted into the USDC price in USD
        uint256 amountTslaInUsdc = getUsdcValueOfUsd(getUsdValueOfTsla(amountdTsla));

        if (amountTslaInUsdc < i_minnimum_withdrwal_amount) {
            revert dTSLA_DosentMeetMinimumWithdrawalAmount();
        }

        FunctionsRequest.Request memory request;
        request.initializeRequestForInlineJavaScript(s_redeemSourceCode);
        /// @dev we have to send the token to the chainlink as the request
        /// but so for that passing as the argument
        string[] memory args = new string[](2);
        args[0] = amountdTsla.toString();
        args[1] = amountTslaInUsdc.toString();
        /// setting the args
        request.setArgs(args);

        bytes32 requestId = _sendRequest(request.encodeCBOR(), i_subscriptionId, i_gasLimit, i_donId);
        s_requestId[requestId].amountOfToken = amountdTsla;
        s_requestId[requestId].requester = msg.sender;
        s_requestId[requestId].mintOrRedeem = MinOrRedeem.redeem;
        s_mostRecentRequestId = requestId;
        _burn(msg.sender, amountdTsla);
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
        dTeslaRequest memory req = s_requestId[requestId];
        if (req.mintOrRedeem == MinOrRedeem.Mint) {
            _mintFulFilRequest(requestId, response);
        } else {
            _redeemFulFilRequest(requestId, response);
        }
        // s_portfolioBalance = uint256(bytes32(response));
    }

    // function finishMint() external onlyOwner{
    //     uint256 amountOfTokenToMint = s_requestId[s_mostRecentRequestId].amountOfToken;
    //     if (_getCollateralRatioAdjustTotalBalance(amountOfTokenToMint) > s_portfolioBalance) {
    //         revert dTSLA_NotEngoughCollateral();
    //     }
    //     _mint(s_requestId[s_mostRecentRequestId].requester, amountOfTokenToMint);
    // }

    function withdraw() external {
        uint256 amountToWithdraw = s_userToWithdrawlAmount[msg.sender];
        s_userToWithdrawlAmount[msg.sender] = 0;

        bool success = ERC20(i_tokenOnSepolia).transfer(msg.sender, amountToWithdraw);
        if (!success) {
            revert dTSLA_TransactionFailed();
        }
    }

    function getCalculatedNewTokenValue(uint256 amountOfTokenToMint) public view returns (uint256) {
        return ((totalSupply() + amountOfTokenToMint) * getTslaPrice()) / i_precision;
    }

    function getUsdcValueOfUsd(uint256 amount) public view returns (uint256) {
        return (amount * getUsdcPrice()) / i_precision;
    }

    function getUsdValueOfTsla(uint256 tslAmount) public view returns (uint256) {
        return (tslAmount * getTslaPrice()) / i_precision;
    }

    //// return the TSLA price in USDC
    function getTslaPrice() public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(i_teslaUSD);
        (, int256 priceOfTslaInUSDC,,,) = priceFeed.latestRoundData();
        return uint256(priceOfTslaInUSDC) * i_tsla_price_decimal_precision;
    }

    //// return the USDC price in USDC
    function getUsdcPrice() public view returns (uint256) {
        {
            AggregatorV3Interface priceFeed = AggregatorV3Interface(i_usdcUSD);
            (, int256 priceOfTslaInUSDC,,,) = priceFeed.latestRoundData();
            return uint256(priceOfTslaInUSDC) * i_tsla_price_decimal_precision;
        }
    }

    /*//////////////////////////////////////////////////////////////
                              VIEW AND PURE
    //////////////////////////////////////////////////////////////*/
    function getRequest(bytes32 requestId) public view returns (dTeslaRequest memory) {
        return s_requestId[requestId];
    }

    function getPortfolioBalance() public view returns (uint256) {
        return s_portfolioBalance;
    }

    function getSubId() public view returns (uint64) {
        return i_subscriptionId;
    }

    function getMintSourceCode() public view returns (string memory) {
        return s_mintSourceCode;
    }

    function getRedeemSourceCode() public view returns (string memory) {
        return s_redeemSourceCode;
    }

    function getCollateralRatio() public view returns (uint256) {
        return i_collateral_ratio;
    }

    function getCollateralPrecision() public view returns (uint256) {
        return i_collateral_precesion;
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

    function _redeemFulFilRequest(bytes32 requestId, bytes memory response) internal {
        // assume for now this has 18 decimals
        uint256 usdcAmount = uint256(bytes32(response));
        if (usdcAmount == 0) {
            uint256 mountOfdTSLABurned = s_requestId[requestId].amountOfToken;
            _mint(s_requestId[requestId].requester, mountOfdTSLABurned);
            return;
        }
        s_userToWithdrawlAmount[s_requestId[requestId].requester] += usdcAmount;
    }

    /// this function convert the minted
    function _getCollateralRatioAdjustTotalBalance(uint256 amountOfToken) internal view returns (uint256) {
        uint256 calaculatedNewTokenValue = getCalculatedNewTokenValue(amountOfToken);
        return (calaculatedNewTokenValue * i_collateral_ratio) / i_collateral_precesion;
    }
}
