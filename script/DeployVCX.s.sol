// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {Create2} from "openzeppelin-contracts/contracts/utils/Create2.sol";
import {VCX} from "../src/VCX.sol";

contract DeployVCX is Script {

    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant Create2Deployer = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

    function run() public returns (VCX vcx) {
        address admin = vm.envAddress("ADMIN");

        // we try to find a salt that deploys VCX at an address that is smaller
        // than WETH.
        uint i = 0;
        bytes32 salt;
        while (true) {
            salt = keccak256(abi.encode("VCX", i));
            address addr = Create2.computeAddress(
                salt,
                keccak256(bytes.concat(
                    type(VCX).creationCode,
                    abi.encode(admin, "VCX", "VaultCraft")
                )),
                Create2Deployer
            );
            if (addr > WETH) {
                break;
            }
            ++i;
        }

        vm.startBroadcast(admin);
        vcx = (new VCX){salt: salt}(admin, "VCX", "VaultCraft");
        vm.stopBroadcast();
    }
}