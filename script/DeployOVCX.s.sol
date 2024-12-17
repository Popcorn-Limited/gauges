// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {oVCXBridge} from "../src/oVCXBridge.sol";
import {oVCXL2} from "../src/oVCX_L2.sol";

// deploy oVCX mainnet bridge
contract DeployOVCXBridge is Script {
    function run() public returns (oVCXBridge bridge) {
        vm.startBroadcast();
        console.log("msg.sender:", msg.sender);

        // oVCX address
        address oVCXToken = address(0);

        // mainnet LZ Endpoint
        address lzEndpoint = address(address(0));

        // deploy - sets msg.sender as owner
        bridge = new oVCXBridge(oVCXToken, lzEndpoint, msg.sender);

        vm.stopBroadcast();
    }
}

// deploys oVCX on L2 and sets peer with mainnet oVCX bridge
contract DeployOVCXL2 is Script {
    function run() public returns (oVCXL2 oVCX) {
        uint32 mainnetEndpointID = 40232; // mainnet EndPoint ID with oVCX bridge adapter
        uint32 l2EndpointID = 40231; // endpoint id of the l2 oVCX being deployed

        vm.startBroadcast();
        console.log("msg.sender:", msg.sender);

        // L2 chain LZ contract address
        address lzEndpoint = address(0); // modify

        // mainnet oVCX bridge adapter
        address bridge = address(0); // modify

        // deploy L2 oVCX - sets msg.sender as owner
        oVCX = new oVCXL2("VCX call option token", "oVCX", lzEndpoint);

        // register l2 -> mainnet peer
        oVCX.setPeer(mainnetEndpointID, addressToBytes32(bridge));

        // register mainnet -> l2 peer
        oVCXBridge(bridge).setPeer(
            l2EndpointID,
            addressToBytes32(address(oVCX))
        );

        vm.stopBroadcast();
    }

    function addressToBytes32(address _addr) public pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }
}

// register new peer - add new chain
contract AddChain is Script {
    function run() public {
        vm.startBroadcast();
        console.log("msg.sender:", msg.sender);

        // mainnet oVCX bridge
        oVCXBridge bridge = oVCXBridge(address(0));
        uint32 mainnetEndpointID = 40232; // mainnet EndPoint ID with oVCX bridge adapter

        // l2 oVCX to register
        uint32 l2EndpointID = 40231; // arbitrum sepolia eID
        address oVCX = address(0);

        // register mainnet -> l2 peer
        bridge.setPeer(l2EndpointID, addressToBytes32(oVCX));

        // register l2 -> mainnet peer
        oVCXL2(oVCX).setPeer(
            mainnetEndpointID,
            addressToBytes32(address(bridge))
        );

        vm.stopBroadcast();
    }

    function addressToBytes32(address _addr) public pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }
}
