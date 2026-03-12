// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {Script, console} from "forge-std/Script.sol";
import {dTSLA} from "../src/dTSLA.sol";
import {HelperScript} from "./HelperScript.s.sol";

contract DeployDTsla is Script {
    HelperScript helper = new HelperScript();
    string constant alpacaMintSourceCode = "./functions/sources/alpacaBalance.js";
    string constant alpacaRedeemSourceCode = "";
    address key = vm.envAddress("PUBLIC_KEY");

    function run() public returns (dTSLA) {
        (
            address routerAddr,
            address teslaUSD,
            address usdcUSD,
            address tokenOnSepolia,
            bytes32 don_ID,
            uint64 subscriptionId,
            uint32 gas_limit,
            uint256 precision,
            uint256 tsla_price_decimal_precision,
            uint256 collateral_ratio,
            uint256 collateral_precesion,
            uint256 minnimum_withdrwal_amount
        ) = helper.s_networkConfig(block.chainid);
        string memory mintSource = vm.readFile(alpacaMintSourceCode);
        vm.startBroadcast(key);
        dTSLA teslaToken = new dTSLA(
            subscriptionId,
            routerAddr,
            mintSource,
            alpacaRedeemSourceCode,
            teslaUSD,
            usdcUSD,
            tokenOnSepolia,
            don_ID,
            gas_limit,
            precision,
            tsla_price_decimal_precision,
            collateral_ratio,
            collateral_precesion,
            minnimum_withdrwal_amount
        );
        vm.stopBroadcast();
        return teslaToken;
    }
}
