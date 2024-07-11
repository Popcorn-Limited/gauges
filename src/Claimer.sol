// SPDX-License-Identifier: GPL-3.0
// Docgen-SOLC: 0.8.0

pragma solidity ^0.8.0;

import {IERC20} from "forge-std/interfaces/IERC20.sol";

import {ILiquidityGauge} from "./interfaces/ILiquidityGauge.sol";

/// @dev This contract is just deployed once to mitigate a configuration issue on the Compound USDC Gauge on Arbitrum
contract Claimer {
    ILiquidityGauge public gauge;
    IERC20 public rewardToken;

    constructor(address gauge_, address rewardToken_) {
        gauge = ILiquidityGauge(gauge_);
        rewardToken = IERC20(rewardToken_);
    }

    function claim() external {
        uint256 claimable = gauge.claimable_reward(
            msg.sender,
            address(rewardToken)
        );
        rewardToken.transfer(address(gauge), claimable);
        gauge.claim_rewards(msg.sender);
    }
}
