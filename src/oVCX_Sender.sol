// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.22;

import {OFTAdapter} from "@layerzerolabs/oft-evm/contracts/OFTAdapter.sol";
import {SendParam, MessagingFee, OFTMsgCodec} from "@layerzerolabs/oft-evm/contracts/OFTCore.sol";
import {IBridger} from "./interfaces/IBridger.sol";

// Bridger contract to lock and bridge oVCX emissions to any chain
// implements IBridger iface to be compatible with gauges
contract oVCXSender is OFTAdapter, IBridger {
    mapping(address => uint32) public supportedGauges;

    address public defaultGauge; // used to estimate a "default" bridging cost

    constructor(
        address _token,
        address _lzEndpoint,
        address _owner
    ) OFTAdapter(_token, _lzEndpoint, _owner) {}

    // whitelist a destination address (gauge)
    function addGauge(address gauge, uint32 destEid) external onlyOwner {
        if(defaultGauge == address(0)) 
            defaultGauge = gauge; 

        supportedGauges[gauge] = destEid;
    }

    // update default gauge
    function setDefaultGauge(address gauge, uint32 destEid) external onlyOwner {
        defaultGauge = gauge;

        supportedGauges[gauge] = destEid;
    }

    // called by RootGaugeFactory with msg.sender originating the tx
    // implements IBridger iface - check the originator sender
    function check(address) external view returns (bool) {
        return true;
    }

    // called by RootGaugeFactory to estimate msg.value necessary for bridging
    // implements IBridger iface
    function cost() external view returns (uint256) {
        return _quoteSend(defaultGauge, 1e18);
    }

    // get msg.value necessary to bridge to a speficic chain
    function quote(
        address destinationGauge,
        uint256 amount
    ) external view returns (uint256 value) {
        return _quoteSend(destinationGauge, amount);
    }

    // bridges to the destination address via LZ
    function bridge(address, address dest, uint256 amount) external payable {
        uint32 destEid = supportedGauges[dest];
        require(destEid != 0, "Add gauge");

        // lock tokens in the adapter
        (uint256 amountSentLD, ) = _debit(msg.sender, amount, amount, destEid);

        // build LZ message and options
        (bytes memory message, bytes memory options) = _getMessageAndOptions(
            _addressToBytes32(dest),
            amountSentLD
        );

        // Sends the message to the LayerZero endpoint
        _lzSend(
            destEid,
            message,
            options,
            MessagingFee(msg.value, 0),
            msg.sender
        );
    }

    // builds crosschain message and ask for a quote to LZ endpoint
    function _quoteSend(
        address receiver,
        uint256 amount
    ) internal view returns (uint256) {
        uint32 destinationEndpointId = supportedGauges[receiver];
        require(destinationEndpointId != 0, "Add gauge");

        SendParam memory sendParams = SendParam(
            destinationEndpointId,
            _addressToBytes32(receiver),
            amount,
            amount,
            hex"",
            hex"",
            hex""
        );

        // simulate a debit call
        (uint256 amountSendLD, ) = _debitView(
            sendParams.amountLD,
            sendParams.minAmountLD,
            sendParams.dstEid
        );

        // build LZ message and options
        (bytes memory message, bytes memory options) = _getMessageAndOptions(
            sendParams.to,
            amountSendLD
        );

        // quote LZ endpoint for a fee value
        MessagingFee memory fee = _quote(
            sendParams.dstEid,
            message,
            options,
            false
        );

        return fee.nativeFee;
    }

    function _getMessageAndOptions(
        bytes32 destAddr,
        uint256 amountSentLD
    ) internal view returns (bytes memory m, bytes memory o) {
        (m, ) = OFTMsgCodec.encode(destAddr, _toSD(amountSentLD), hex"");

        // hardcoded options for a vanilla OFT bridge
        o = hex"0003010011010000000000000000000000000000ea60";
    }

    function _addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }
}
