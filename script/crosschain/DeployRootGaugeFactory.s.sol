// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.13;

import {CREATE3Script} from "../base/CREATE3Script.sol";
import {VyperDeployer} from "../../src/lib/VyperDeployer.sol";

import {IRootGauge} from "../../src/interfaces/IRootGauge.sol";
import {IRootGaugeFactory} from "../../src/interfaces/IRootGaugeFactory.sol";

contract DeployRootGaugeFactoryScript is CREATE3Script, VyperDeployer {
    constructor() CREATE3Script(vm.envString("VERSION")) {}

    function run() public returns (IRootGauge rootGaugeTemplate, IRootGaugeFactory rootGaugeFactory) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        vm.startBroadcast(deployerPrivateKey);

        address admin = vm.envAddress("ADMIN");

        rootGaugeTemplate = IRootGauge(
            createx.deployCreate3(
                getCreate3ContractSalt("RootGauge"),
                bytes.concat(compileContract("RootGauge"), abi.encode(getCreate3Contract("Minter")))
            )
        );

        rootGaugeFactory = IRootGaugeFactory(
            createx.deployCreate3(
                getCreate3ContractSalt("RootGaugeFactory"),
                bytes.concat(compileContract("RootGaugeFactory"), abi.encode(admin, rootGaugeTemplate))
            )
        );

        vm.stopBroadcast();
    }
}
