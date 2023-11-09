// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {Create2} from "openzeppelin-contracts/contracts/utils/Create2.sol";
import {VCX} from "../src/VCX.sol";

contract DeployVCX is Script {

    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    function run() public returns (VCX vcx) {
        address admin = vm.envAddress("ADMIN");

        // we try to find a salt that deploys VCX at an address that is smaller
        // than WETH.
        uint i = 0;
        bytes32 salt;
        while (true) {
            salt = keccak256(abi.encode("VCX", i));
            if (Create2.computeAddress(salt, keccak256(type(VCX).creationCode)) < WETH) {
                break;
            }
            ++i;
        }

        vm.startBroadcast(admin);
        vcx = (new VCX){salt: salt}("VCX", "VCX");
        vm.stopBroadcast();
    }
}