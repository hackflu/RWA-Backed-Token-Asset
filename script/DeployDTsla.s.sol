// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {Script, console} from "forge-std/Script.sol";
import {dTSLA} from "../src/dTSLA.sol";

contract DeployDTsla is Script {
    uint64 constant subscriptionId = 6299;
    address private constant router =
        0xb83E47C2bC239B3bf370bc41e1459A34b41238D0;
    string constant alpacaMintSourceCode =
        "./functions/sources/alpacaBalance.js";
    string constant alpacaRedeemSourceCode = "";

    function run() public {
        string memory mintSource = vm.readFile(alpacaMintSourceCode);
        vm.startBroadcast();
        dTSLA dTSLA = new dTSLA(
            subscriptionId,
            router,
            mintSource,
            alpacaRedeemSourceCode
        );
        vm.stopBroadcast();
        console.log(address(dTSLA));
    }
}
