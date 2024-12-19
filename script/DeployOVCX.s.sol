// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {OVCXBridge} from "../src/oVCXBridge.sol";
import {oVCXL2} from "../src/oVCX_L2.sol";

// 1 - DeployOVCXBridge on root chain
// 2 - WhitelistReceiver on root chain
// 3 - DeployOVCXL2 on recipient chain
// 4 - SetReceiverPeer on root chain

// ------------------------------- ROOT LZ APP ------------------------------- //

// deploy LZ oVCX Root bridge
contract DeployOVCXBridge is Script {
    function run() public returns (OVCXBridge bridge) {
        vm.startBroadcast();
        console.log("msg.sender:", msg.sender);

        // oVCX address
        address tokenToBridge = address(
            0xb1D4538B4571d411F07960EF2838Ce337FE1E80E
        ); // modify

        // see https://docs.layerzero.network/v2/developers/evm/technical-reference/deployed-contracts
        address lzEndpoint = address(
            0x6EDCE65403992e310A62460808c4b910D972f10f
        ); // modify

        // deploy
        address owner = msg.sender;
        bridge = new OVCXBridge(tokenToBridge, lzEndpoint, owner);

        vm.stopBroadcast();
    }
}

// to whitelist new address that can receive crosschain token from bridge
contract WhitelistReceiver is Script {
    function run() public {
        vm.startBroadcast();
        console.log("msg.sender:", msg.sender);

        // initialize bridge
        OVCXBridge bridge = OVCXBridge(
            address(0x545C512775aad7541C9388E0cBF1aD300658Ee92)
        ); // modify

        // whitelist receiver and LZ endpoint id
        address receiverToWhitelist = address(
            0x9bE75Bc132923847290677328b8FFB15d3081f2c
        ); // modify
        uint32 destinationEndpointId = 40232; // modify

        bridge.addGauge(receiverToWhitelist, destinationEndpointId);

        vm.stopBroadcast();
    }
}

// to register a new chain: set peer with LZ receiver contract
contract SetReceiverPeer is Script {
    function run() public {
        vm.startBroadcast();
        console.log("msg.sender:", msg.sender);

        // initialize bridge
        OVCXBridge bridge = OVCXBridge(
            address(0x545C512775aad7541C9388E0cBF1aD300658Ee92)
        ); // modify

        // set LZ peer to receiver app
        uint32 destinationEndpointId = 40232; // LZ receiver endpoint ID
        address destinationLZPeer = address(
            0x870C872320d599fE6C9158C9DddeA01A08F2aE1c
        ); // LZ receiver app

        bridge.setPeer(
            destinationEndpointId,
            addressToBytes32(destinationLZPeer)
        );

        vm.stopBroadcast();
    }

    function addressToBytes32(address _addr) public pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }
}

// ------------------------------- RECEIVER LZ APP ------------------------------- //

// deploys oVCX on L2 and sets peer with root oVCX bridge
contract DeployOVCXL2 is Script {
    function run() public returns (oVCXL2 oVCX) {
        uint32 receiverEndpointID = 40232; // LZ endpointID of the receiver being deployed
        uint32 rootEndpointID = 40231; // LZ endpointID of the root bridge

        vm.startBroadcast();
        console.log("msg.sender:", msg.sender);

        // see https://docs.layerzero.network/v2/developers/evm/technical-reference/deployed-contracts
        address lzEndpoint = address(
            0x6EDCE65403992e310A62460808c4b910D972f10f
        ); // modify

        // root bridge address
        address bridge = address(0x545C512775aad7541C9388E0cBF1aD300658Ee92); // modify

        // deploy L2 oVCX - sets msg.sender as owner
        oVCX = new oVCXL2("VCX call option token", "oVCX", lzEndpoint);

        // set peer with root bridge
        oVCX.setPeer(rootEndpointID, addressToBytes32(bridge));

        vm.stopBroadcast();
    }

    function addressToBytes32(address _addr) public pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }
}
