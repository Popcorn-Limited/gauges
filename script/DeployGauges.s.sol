// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {CREATE3Script, console} from "./base/CREATE3Script.sol";
import {ILiquidityGauge} from "../src/interfaces/ILiquidityGauge.sol";
import {PopcornLiquidityGaugeFactory} from "../src/PopcornLiquidityGaugeFactory.sol";

contract DeployScript is CREATE3Script {
    constructor() CREATE3Script(vm.envString("VERSION")) {}

    function run() public returns (ILiquidityGauge[] memory gauges) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        vm.startBroadcast(deployerPrivateKey);

        PopcornLiquidityGaugeFactory factory =
            PopcornLiquidityGaugeFactory(getCreate3Contract("PopcornLiquidityGaugeFactory"));

        address[] memory vaults = vm.envAddress("INITIAL_VAULTS", ",");
        gauges = new ILiquidityGauge[](vaults.length);
        for (uint256 i; i < vaults.length; ) {
            gauges[i] = ILiquidityGauge(factory.create(vaults[i], 1e18));
        
            unchecked {
                ++i;
            }
        }

        vm.stopBroadcast();
    }
}
