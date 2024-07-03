// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.13;

import {CREATE3Script, console} from "./base/CREATE3Script.sol";
import {ILiquidityGauge} from "../src/interfaces/ILiquidityGauge.sol";
import {IChildGaugeFactory} from "../src/interfaces/IChildGaugeFactory.sol";

contract DeployScript is CREATE3Script {
    IChildGaugeFactory factory =
        IChildGaugeFactory(0x6aa03ebAb1e9CB8d44Fd79153d3a258FFd48169A);

    constructor() CREATE3Script(vm.envString("VERSION")) {}

    function run() public returns (ILiquidityGauge[] memory gauges) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        console.log("msg.sender: ", msg.sender);

        // @dev Only include vaults from the same chain
        address[] memory vaults = vm.envAddress("INITIAL_VAULTS", ",");

        gauges = new ILiquidityGauge[](vaults.length);
        for (uint256 i; i < vaults.length; ) {
            console.log("vault: ", vaults[i]);
            gauges[i] = ILiquidityGauge(factory.deploy_gauge(vaults[i]));

            gauges[i].set_tokenless_production(20);

            unchecked {
                ++i;
            }
        }
        vm.stopBroadcast();
    }
}
