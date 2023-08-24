// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {CREATE3Script, console} from "./base/CREATE3Script.sol";
import {ILiquidityGauge} from "../src/interfaces/ILiquidityGauge.sol";
import {PopcornLiquidityGaugeFactory} from "../src/PopcornLiquidityGaugeFactory.sol";
import {IGaugeController} from "../src/interfaces/IGaugeController.sol";

contract DeployScript is CREATE3Script {
    constructor() CREATE3Script(vm.envString("VERSION")) {}

    function run() public returns (ILiquidityGauge[] memory gauges) {
        address admin = vm.envAddress("ADMIN");
        vm.startBroadcast(admin);

        PopcornLiquidityGaugeFactory factory =
            PopcornLiquidityGaugeFactory(getCreate3Contract("PopcornLiquidityGaugeFactory"));

        IGaugeController controller = IGaugeController(getCreate3Contract("GaugeController"));
        controller.add_type("Ethereum", 1);
        address[] memory vaults = vm.envAddress("INITIAL_VAULTS", ",");
        gauges = new ILiquidityGauge[](vaults.length);
        for (uint256 i; i < vaults.length; ) {
            gauges[i] = ILiquidityGauge(factory.create(vaults[i], 1e18));
        
            controller.add_gauge(address(gauges[i]), 0, 1);
        
            unchecked {
                ++i;
            }
        }

        vm.stopBroadcast();
    }
}
