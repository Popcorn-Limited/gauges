// SPDX-License-Identifier: GPL-3.0
// Docgen-SOLC: 0.8.0

pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {Claimer, IERC20, ILiquidityGauge} from "src/Claimer.sol";

contract ClaimerTest is Test {
    address ovcx = 0x59a696bF34Eae5AD8Fd472020e3Bed410694a230;
    address gauge = 0xc9aD14cefb29506534a973F7E0E97e68eCe4fa3f;
    address user = 0x22f5413C075Ccd56D575A54763831C4c27A37Bdb;
    address funder = 0x6aa03ebAb1e9CB8d44Fd79153d3a258FFd48169A;

    Claimer claimer;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("arbitrum"));

        claimer = new Claimer(gauge, ovcx);
    }

    function test__allows_claiming() public {
        vm.prank(funder);
        IERC20(ovcx).transfer(address(claimer), 100e18);

        uint256 claimable = ILiquidityGauge(gauge).claimable_reward(user, ovcx);
        uint256 oldBal = IERC20(ovcx).balanceOf(user);

        vm.prank(user);
        claimer.claim();

        assertEq(IERC20(ovcx).balanceOf(user), oldBal + claimable);
        assertEq(IERC20(ovcx).balanceOf(address(claimer)), 100e18 - claimable);
        assertEq(IERC20(ovcx).balanceOf(gauge), 0);
    }

    function testFail__claim_fails_zero_rewardTokens() public {
        vm.prank(user);
        claimer.claim();
    }
}
