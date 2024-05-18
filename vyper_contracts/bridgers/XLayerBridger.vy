# @version 0.3.7
"""
@title XLayer Bridge Wrapper
"""
from vyper.interfaces import ERC20

interface XLayerBridge:
    def bridgeAsset(_destinationNetwork: uint32, _destinationAddress: address, _amount: uint256, _token: address, _forceUpdateGlobalExitRoot: bool, permitData: Bytes[128]): payable

TOKEN: immutable(address)
XLAYER_BRIDGE: immutable(address)
# 1 = XLayer testnet
# 3 = XLayer mainnet
# see https://www.okx.com/xlayer/docs/developer/build-on-xlayer/bridge-to-xlayer
XLAYER_NETWORK_ID: immutable(uint32)

is_approved: public(HashMap[address, bool])

@external
def __init__(_token: address, _xlayer_bridge: address, _xlayer_network_id: uint32):
    TOKEN = _token
    XLAYER_BRIDGE = _xlayer_bridge
    XLAYER_NETWORK_ID = _xlayer_network_id

    assert ERC20(_token).approve(_xlayer_bridge, max_value(uint256), default_return_value=True)
    self.is_approved[_token] = True

@external
def bridge(_token: address, _to: address, _amount: uint256):
    """
    @notice Bridge a token to XLayer mainnet using the L1 Standard Bridge
    @param _token The token to bridge
    @param _to The address to deposit the token to on L2
    @param _amount The amount of the token to deposit
    """
    assert ERC20(_token).transferFrom(msg.sender, self, _amount, default_return_value=True)
    if _token != TOKEN and not self.is_approved[_token]:
        assert ERC20(_token).approve(XLAYER_BRIDGE, max_value(uint256), default_return_value=True)
        self.is_approved[_token] = True

    XLayerBridge(XLAYER_BRIDGE).bridgeAsset(XLAYER_NETWORK_ID, _to, _amount, _token, True, b"")


@pure
@external
def cost() -> uint256:
    """
    @notice Cost in OKB to bridge
    """
    return 0


@pure
@external
def check(_account: address) -> bool:
    """
    @notice Check if `_account` may bridge via `transmit_emissions`
    @param _account The account to check
    """
    return True