// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.22;

import { OFT } from "@layerzerolabs/oft-evm/contracts/OFT.sol";

// oVCX on L2: ERC20 + Layer Zero receiver 
contract oVCXL2 is OFT {
    mapping(address => uint32) public supportedGauges;

    // todo hardcode ovcx addr?
    constructor(
        string memory _name,
        string memory _symbol,
        address _lzEndpoint
    ) OFT(_name, _symbol, _lzEndpoint, msg.sender) {}

    // set a layer zero endpoint ID for bridging gauge rewards
    function addGauge(address gauge, uint32 destEid) external onlyOwner {
        supportedGauges[gauge] = destEid;
    }
}