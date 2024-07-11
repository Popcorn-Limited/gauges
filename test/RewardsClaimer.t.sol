pragma solidity >=0.8.0;
import "forge-std/Test.sol";

import {IERC20} from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";

import {WrappedToken} from "src/WrappedToken.sol";
import {RewardsClaimer, ILiquidityGauge} from "src/RewardsClaimer.sol";

contract RewardsClaimerTest is Test {
    IERC20 public underlying =
        IERC20(0x59a696bF34Eae5AD8Fd472020e3Bed410694a230);
    WrappedToken public wrappedToken =
        WrappedToken(0xaF33642938172011f711bA530acc900Ae17620A7);
    ILiquidityGauge public gauge =
        ILiquidityGauge(0x5E6A9859Dc1b393a82a5874F9cBA22E92d9fbBd2);

    RewardsClaimer claimer;

    address user = 0x22f5413C075Ccd56D575A54763831C4c27A37Bdb;
    address admin = 0x2C3B135cd7dc6C673b358BEF214843DAb3464278;
    address whale = 0x63421beE7a26966156403FF1c8ACBE79c2EaFB1f;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("arbitrum"));

        claimer = new RewardsClaimer(address(wrappedToken));
    }

    function test___claimAndUnwrap() public {
        // Prepare Rewards
        vm.startPrank(whale);
        underlying.approve(address(wrappedToken), 1e22);
        wrappedToken.wrap(1e22);
        wrappedToken.approve(address(gauge), 1e22);
        vm.stopPrank();

        vm.prank(admin);
        gauge.add_reward(address(wrappedToken), whale);

        vm.prank(whale);
        gauge.deposit_reward_token(address(wrappedToken), 1e22);

        // Actual Test
        vm.warp(block.timestamp + 7 days);
        uint256 userUnderlyingBal = underlying.balanceOf(user);
        uint256 userWrappedBal = wrappedToken.balanceOf(user);
        uint256 gaugeUnderlyingBal = underlying.balanceOf(address(gauge));
        uint256 gaugeWrappedBal = wrappedToken.balanceOf(address(gauge));

        vm.prank(user);
        wrappedToken.approve(address(claimer), type(uint256).max);

        vm.prank(user);
        claimer.claimAndUnwrap(address(gauge));

        assertGt(underlying.balanceOf(user), userUnderlyingBal);
        assertEq(wrappedToken.balanceOf(user), userWrappedBal);

        assertEq(underlying.balanceOf(address(gauge)), gaugeUnderlyingBal);
        assertLt(wrappedToken.balanceOf(address(gauge)), gaugeWrappedBal);

        assertEq(underlying.balanceOf(address(claimer)), 0);
        assertEq(wrappedToken.balanceOf(address(claimer)), 0);
    }

    function test___claimAndUnwrap_no_wrapped() public {
        // Actual Test
        vm.warp(block.timestamp + 7 days);
        uint256 userUnderlyingBal = underlying.balanceOf(user);
        uint256 userWrappedBal = wrappedToken.balanceOf(user);
        uint256 gaugeUnderlyingBal = underlying.balanceOf(address(gauge));
        uint256 gaugeWrappedBal = wrappedToken.balanceOf(address(gauge));

        vm.prank(user);
        claimer.claimAndUnwrap(address(gauge));

        assertEq(underlying.balanceOf(user), userUnderlyingBal);
        assertEq(wrappedToken.balanceOf(user), userWrappedBal);

        assertEq(underlying.balanceOf(address(gauge)), gaugeUnderlyingBal);
        assertEq(wrappedToken.balanceOf(address(gauge)), gaugeWrappedBal);

        assertEq(underlying.balanceOf(address(claimer)), 0);
        assertEq(wrappedToken.balanceOf(address(claimer)), 0);
    }

    function testFail___claimAndUnwrap_not_approved() public {
        // Prepare Rewards
        vm.startPrank(whale);
        underlying.approve(address(wrappedToken), 1e22);
        wrappedToken.wrap(1e22);
        wrappedToken.approve(address(gauge), 1e22);
        vm.stopPrank();

        vm.prank(admin);
        gauge.add_reward(address(wrappedToken), whale);

        vm.prank(whale);
        gauge.deposit_reward_token(address(wrappedToken), 1e22);

        // Actual Test
        vm.warp(block.timestamp + 7 days);
        uint256 userUnderlyingBal = underlying.balanceOf(user);
        uint256 userWrappedBal = wrappedToken.balanceOf(user);
        uint256 gaugeUnderlyingBal = underlying.balanceOf(address(gauge));
        uint256 gaugeWrappedBal = wrappedToken.balanceOf(address(gauge));

        vm.prank(user);
        claimer.claimAndUnwrap(address(gauge));
    }
}
