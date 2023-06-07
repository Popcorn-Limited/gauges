# @version 0.3.7
"""
@title Curve Optimism Bridge Wrapper
"""
from vyper.interfaces import ERC20


event UpdateTokenMapping:
    _l1_token: indexed(address)
    _old_l2_token: address
    _new_l2_token: address

event TransferOwnership:
    _old_owner: address
    _new_owner: address

OPTIMISM_L1_BRIDGE: constant(address) = 0x99C9fc46f92E8a1c0deC1b1747d010903E884bE1

TOKEN: immutable(address)
L2_TOKEN: immutable(address)

# l1_token -> l2_token
l2_token: public(HashMap[address, address])

owner: public(address)
future_owner: public(address)


@external
def __init__(_token: address, _l2_token: address):
    TOKEN = _token
    L2_TOKEN = _l2_token

    assert ERC20(_token).approve(OPTIMISM_L1_BRIDGE, max_value(uint256), default_return_value=True)
    self.l2_token[_token] = _l2_token

    self.owner = msg.sender
    log TransferOwnership(empty(address), msg.sender)


@external
def bridge(_token: address, _to: address, _amount: uint256):
    """
    @notice Bridge a token to Optimism mainnet using the L1 Standard Bridge
    @param _token The token to bridge
    @param _to The address to deposit the token to on L2
    @param _amount The amount of the token to deposit
    """
    assert ERC20(_token).transferFrom(msg.sender, self, _amount, default_return_value=True)

    l2_token: address = L2_TOKEN
    if _token != TOKEN:
        l2_token = self.l2_token[_token]
        assert l2_token != empty(address)  # dev: token not mapped

    raw_call(
        OPTIMISM_L1_BRIDGE,
        _abi_encode(
            _token,
            l2_token,
            _to,
            _amount,
            convert(200_000, uint256),
            b"",
            method_id=method_id("depositERC20To(address,address,address,uint256,uint32,bytes)")
        )
    )


@view
@external
def check(_account: address) -> bool:
    """
    @notice Dummy method to check if caller is allowed to bridge
    @param _account The account to check
    """
    return True


@view
@external
def cost() -> uint256:
    """
    @notice Cost in ETH to bridge
    """
    return 0


@external
def set_l2_token(_l1_token: address, _l2_token: address):
    """
    @notice Set the mapping of L1 token -> L2 token for depositing
    @param _l1_token The l1 token address
    @param _l2_token The l2 token address
    """
    assert msg.sender == self.owner
    assert _l1_token != TOKEN  # dev: cannot reset mapping for TOKEN

    amount: uint256 = 0
    if _l2_token != empty(address):
        amount = max_value(uint256)
    assert ERC20(_l1_token).approve(OPTIMISM_L1_BRIDGE, amount, default_return_value=True)

    log UpdateTokenMapping(_l1_token, self.l2_token[_l1_token], _l2_token)
    self.l2_token[_l1_token] = _l2_token


@external
def commit_transfer_ownership(_future_owner: address):
    """
    @notice Transfer ownership to `_future_owner`
    @param _future_owner The account to commit as the future owner
    """
    assert msg.sender == self.owner  # dev: only owner

    self.future_owner = _future_owner


@external
def accept_transfer_ownership():
    """
    @notice Accept the transfer of ownership
    @dev Only the committed future owner can call this function
    """
    assert msg.sender == self.future_owner  # dev: only future owner

    log TransferOwnership(self.owner, msg.sender)
    self.owner = msg.sender