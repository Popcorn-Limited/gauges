// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.22;

import {OFTAdapter} from "@layerzerolabs/oft-evm/contracts/OFTAdapter.sol";
import {SendParam, MessagingFee, OFTMsgCodec} from "@layerzerolabs/oft-evm/contracts/OFTCore.sol";
import {IBridger} from "./interfaces/IBridger.sol";

// Bridger contract to lock and bridge oVCX emissions to any chain
// implements IBridger iface to be compatible with gauges
contract oVCXBridge is OFTAdapter, IBridger {
    mapping(address => uint32) public supportedGauges;

    // todo hardcode ovcx addr?
    constructor(
        address _token,
        address _lzEndpoint,
        address _owner
    ) OFTAdapter(_token, _lzEndpoint, _owner) {}

    // set a layer zero endpoint ID for bridging gauge rewards
    function addGauge(address gauge, uint32 destEid) external onlyOwner {
        supportedGauges[gauge] = destEid;
    }

    // estimate msg.value needed for a a generic ovcx bridge call // TODO
    function cost() external view returns (uint256) {}

    // get msg.value necessary to bridge
    function quote(
        address destinationGauge,
        uint256 amount
    ) external view returns (uint256 value) {
        uint32 destEid = supportedGauges[destinationGauge];
        require(destEid != 0, "Add gauge");

        _quoteSend(
            SendParam(
                destEid,
                _addressToBytes32(destinationGauge),
                amount,
                amount,
                hex"",
                hex"",
                hex""
            ),
            false
        );
    }

    function bridge(
        address token,
        address dest,
        uint256 amount
    ) external payable {
        // TODO token check ?

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

    function _quoteSend(
        SendParam memory _sendParam,
        bool _payInLzToken
    ) internal view returns (MessagingFee memory msgFee) {
        // simulate a debit call
        (uint256 amountSendLD, uint256 amountReceivedLD) = _debitView(
            _sendParam.amountLD,
            _sendParam.minAmountLD,
            _sendParam.dstEid
        );

        // build LZ message and options
        (bytes memory message, bytes memory options) = _getMessageAndOptions(
            _sendParam.to,
            amountSendLD
        );

        // Calculates the LayerZero fee
        return _quote(_sendParam.dstEid, message, options, _payInLzToken);
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
