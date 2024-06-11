// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.13;

import {CREATE3Script, console} from "./base/CREATE3Script.sol";
import {IRootGaugeFactory} from "../src/interfaces/IRootGaugeFactory.sol";
import {IGaugeController} from "../src/interfaces/IGaugeController.sol";
import {ILiquidityGauge} from "../src/interfaces/ILiquidityGauge.sol";

contract DeployScript is CREATE3Script {
    IRootGaugeFactory factory =
        IRootGaugeFactory(0x6aa03ebAb1e9CB8d44Fd79153d3a258FFd48169A);

    IGaugeController controller =
        IGaugeController(0xD57d8EEC36F0Ba7D8Fd693B9D97e02D8353EB1F4);

    constructor() CREATE3Script(vm.envString("VERSION")) {}

    function run() public returns (ILiquidityGauge[] memory gauges) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // ------ chainId to gauge type ------
        // chainId - gauge types
        // 1       - [0,1,2]
        // 10      - 3
        // 42161   - 4
        // -----------------------------------

        // @dev edit these
        uint256 chainId = 10;
        int128 gaugeType = 3;

        // @dev Only include vaults from the same chain
        address[] memory vaults = vm.envAddress("INITIAL_VAULTS", ",");

        gauges = new ILiquidityGauge[](vaults.length);
        for (uint256 i; i < vaults.length; ) {
            gauges[i] = ILiquidityGauge(
                factory.deploy_gauge(chainId, vaults[i], 1e18)
            );

            controller.add_gauge(address(gauges[i]), gaugeType, 1);

            unchecked {
                ++i;
            }
        }
        vm.stopBroadcast();
    }
}
