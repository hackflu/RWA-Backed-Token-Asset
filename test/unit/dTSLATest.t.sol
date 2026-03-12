// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;
import {Test,console} from "forge-std/Test.sol";
import {dTSLA} from "../../src/dTSLA.sol";
import {DeployDTsla} from "../../script/DeployDTsla.s.sol";
import {IFunctionsSubscriptions} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/interfaces/IFunctionsSubscriptions.sol";
import {HelperScript} from "../../script/HelperScript.s.sol";

contract dTSLATest is Test {
    string key = "SEPOLIA_RPC_URL";
    string public_key = "PUBLIC_KEY";
    address PUBLIC_KEY;
    address routerAddr;
    uint64 subscriptionId;
    uint256 collateral_ratio;
    uint256 collateral_precesion;
    DeployDTsla deployTsla;
    dTSLA teslaToken;
    HelperScript helper;
    function setUp() public {
        PUBLIC_KEY = vm.envAddress(public_key);
        string memory TESTNET_RPC_URL = vm.envString(key);
        uint256 forkId = vm.createSelectFork(TESTNET_RPC_URL);
        vm.selectFork(forkId);
        helper = new HelperScript();
        (routerAddr,
            ,
            ,
            ,
            ,
        subscriptionId,
            ,
            ,
            ,
        collateral_ratio,
        collateral_precesion,
            ) = helper.s_networkConfig(block.chainid);
        deployTsla = new DeployDTsla();
        teslaToken = deployTsla.run();
    }

    /*//////////////////////////////////////////////////////////////
                             SENDMINTREQUEST
    //////////////////////////////////////////////////////////////*/
    function testSendMintRequest() public {
        // only callable by owner
        vm.startPrank(PUBLIC_KEY);
        IFunctionsSubscriptions(routerAddr).addConsumer(subscriptionId, address(teslaToken));
        vm.expectEmit(false , false , false ,true,address(teslaToken));
        emit dTSLA.dTSLA__sendMintRequested(100e18);
        bytes32 requestId = teslaToken.sendMintRequest(100e18);
        vm.stopPrank();
        assertEq(subscriptionId, teslaToken.getSubId());
        assertEq(100e18, teslaToken.getRequest(requestId).amountOfToken);
    }

    /*//////////////////////////////////////////////////////////////
                             FULFILLREQUEST
    //////////////////////////////////////////////////////////////*/
    function testFulfillRequest() public {
        string memory value = "error occured";
        vm.startPrank(PUBLIC_KEY);
        // 1. added the consumer
        IFunctionsSubscriptions(routerAddr).addConsumer(subscriptionId, address(teslaToken));
        // 2. send mint request
        bytes32 requestId = teslaToken.sendMintRequest(200e18);
        vm.stopPrank();
        // 3. fulfill request
        vm.startPrank(routerAddr);
        uint256 tokenValue  = teslaToken.getCalculatedNewTokenValue(200e18);
        uint256 tokenAdjustedBalance = (tokenValue * collateral_ratio) / collateral_precesion;
        teslaToken.handleOracleFulfillment(requestId, abi.encode(bytes32(uint256(tokenAdjustedBalance))), abi.encode(value));
        vm.stopPrank();
        assertEq(tokenAdjustedBalance , teslaToken.getPortfolioBalance());
    }

    /*//////////////////////////////////////////////////////////////
                            SENDREDEEMREQUEST
    //////////////////////////////////////////////////////////////*/
    function testSendRedeemRequest() public {
        vm.startPrank(PUBLIC_KEY);
        IFunctionsSubscriptions(routerAddr).addConsumer(subscriptionId, address(teslaToken));
        bytes32 requestId = teslaToken.sendMintRequest(200e18);
        vm.stopPrank();
        // full fill request
        vm.startPrank(routerAddr);
        uint256 tokenValue  = teslaToken.getCalculatedNewTokenValue(200e18);
        uint256 tokenAdjustedBalance = (tokenValue * collateral_ratio) / collateral_precesion;
        teslaToken.handleOracleFulfillment(requestId, abi.encode(bytes32(uint256(tokenAdjustedBalance))), abi.encode(""));
        vm.stopPrank();
        console.log("token adjusted value : ",tokenAdjustedBalance);

        // redeem request
        vm.startPrank(PUBLIC_KEY);
        teslaToken.sendRedeemRequest(200e18);
        vm.stopPrank();
        console.log("current portfolio balance after redeem request : ",teslaToken.getPortfolioBalance());
    }

}