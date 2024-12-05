// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.13;

import {CREATE3Script} from "../base/CREATE3Script.sol";
import {VyperDeployer} from "../../src/lib/VyperDeployer.sol";

contract DeployXLayerBridgerScript is CREATE3Script, VyperDeployer {
    constructor() CREATE3Script(vm.envString("VERSION")) {}

    function run() public returns (address bridger) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        vm.startBroadcast(deployerPrivateKey);

        address xLayerMainnetBridge = 0x2a3DD3EB832aF982ec71669E178424b10Dca2EDe;
        // 1 = XLayer testnet
        // 3 = XLayer mainnet
        // see https://www.okx.com/xlayer/docs/developer/build-on-xlayer/bridge-to-xlayer
        uint32 networkId = 3;

        bridger = createx.deployCreate3(
            getCreate3ContractSalt("XLayerBridger"),
            bytes.concat(
                compileContract("bridgers/XLayerBridger"),
                abi.encode(vm.envAddress("oVCX"), xLayerMainnetBridge, networkId)
            )
        );

        vm.stopBroadcast();
    }
}
