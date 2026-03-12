// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";

abstract contract Constant {
    uint32 constant GAS_LIMIT = 300_000;
    uint256 constant PRECISION = 1e18;
    uint256 constant TSLA_PRICE_DECIMAL_PRECISION = 1e10;
    uint256 constant COLLATERAL_RATIO = 200;
    uint256 constant COLLATERAL_PRECESION = 100;
    uint256 constant MINNIMUM_WITHDRWAL_AMOUNT = 100e18;
}

contract HelperScript is Script, Constant {
    struct NetworkConfig {
        address routerAddr;
        address teslaUSD;
        address usdcUSD;
        address tokenOnSepolia;
        bytes32 don_ID;
        uint64 subscriptionId;
        uint32 gas_limit;
        uint256 precision;
        uint256 tsla_price_decimal_precision;
        uint256 collateral_ratio;
        uint256 collateral_precesion;
        uint256 minnimum_withdrwal_amount;
    }
    // error
    error HelperScript__BlockIdNotSet(uint256 blockId);

    mapping(uint256 => NetworkConfig) public s_networkConfig;

    constructor() {
        if (block.chainid == 11155111) {
            s_networkConfig[11155111] = getSepoliaInfo();
        } else {
            revert HelperScript__BlockIdNotSet(block.chainid);
        }
    }

    function getSepoliaInfo() public pure returns (NetworkConfig memory networkConfig) {
        networkConfig = _ConstantData();
        networkConfig.routerAddr = 0xb83E47C2bC239B3bf370bc41e1459A34b41238D0;
        networkConfig.teslaUSD = 0xc59E3633BAAC79493d908e63626716e204A45EdF;
        networkConfig.usdcUSD = 0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E;
        networkConfig.tokenOnSepolia = 0xAF0d217854155ea67D583E4CB5724f7caeC3Dc87;
        networkConfig.don_ID = hex"66756e2d657468657265756d2d7365706f6c69612d3100000000000000000000";
        networkConfig.subscriptionId = 6299;
    }

    function _ConstantData() internal pure returns (NetworkConfig memory networkConfig) {
        networkConfig.collateral_precesion = COLLATERAL_PRECESION;
        networkConfig.collateral_ratio = COLLATERAL_RATIO;
        networkConfig.gas_limit = GAS_LIMIT;
        networkConfig.minnimum_withdrwal_amount = MINNIMUM_WITHDRWAL_AMOUNT;
        networkConfig.precision = PRECISION;
        networkConfig.tsla_price_decimal_precision = TSLA_PRICE_DECIMAL_PRECISION;
    }
}
