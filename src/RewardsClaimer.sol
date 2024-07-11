// SPDX-License-Identifier: GPL-3.0
// Docgen-SOLC: 0.8.0

pragma solidity ^0.8.0;

import {IERC20} from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {ILiquidityGauge} from "./interfaces/ILiquidityGauge.sol";
import {WrappedToken} from "./WrappedToken.sol";

contract RewardsClaimer {
    WrappedToken public wrappedToken;
    IERC20 public underlyingToken;

    constructor(address wrapped) {
        wrappedToken = WrappedToken(wrapped);
        underlyingToken = WrappedToken(wrapped).underlying();
    }

    function claimAndUnwrap(address gauge) external {
        uint256 claimable = ILiquidityGauge(gauge).claimable_reward(
            msg.sender,
            address(wrappedToken)
        );
        
        ILiquidityGauge(gauge).claim_rewards(msg.sender);

        if (claimable > 0) {
            wrappedToken.transferFrom(msg.sender, address(this), claimable);
            wrappedToken.unwrap(claimable);

            underlyingToken.transfer(msg.sender, claimable);
        }
    }
}
