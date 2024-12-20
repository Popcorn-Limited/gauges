// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.22;

import {OFT} from "@layerzerolabs/oft-evm/contracts/OFT.sol";

// oVCX on L2: ERC20 + Layer Zero receiver
contract oVCXRecipient is OFT {
    mapping(address => uint32) public supportedGauges;

    // todo check crosschain origin to be a supported gauge?
    constructor(
        string memory _name,
        string memory _symbol,
        address _lzEndpoint
    ) OFT(_name, _symbol, _lzEndpoint, msg.sender) {}

    // set a layer zero endpoint ID for bridging gauge rewards
    function addGauge(address gauge, uint32 srcEid) external onlyOwner {
        supportedGauges[gauge] = srcEid;
    }

    function _credit(
        address _to,
        uint256 _amountLD,
        uint32 _srcEid
    ) internal override returns (uint256 amountReceivedLD) {
        require(supportedGauges[_to] == _srcEid, "Invalid sender");
        
        return super._credit(_to, _amountLD, _srcEid);
    }
}
