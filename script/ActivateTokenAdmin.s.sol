// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {CREATE3Script, console} from "./base/CREATE3Script.sol";
import {ITokenAdmin} from "../src/interfaces/ITokenAdmin.sol";

contract DeployScript is CREATE3Script {
    constructor() CREATE3Script(vm.envString("VERSION")) {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        ITokenAdmin tokenAdmin = ITokenAdmin(getCreate3Contract("TokenAdmin"));
        tokenAdmin.activate();

        vm.stopBroadcast();
    }
}
