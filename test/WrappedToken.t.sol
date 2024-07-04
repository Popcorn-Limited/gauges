pragma solidity >=0.8.0;
import {Test} from "forge-std/Test.sol";

import {IERC20} from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";

import {WrappedToken} from "src/WrappedToken.sol";

contract WrappedTokenTest is Test {
    IERC20 public vcx = IERC20(0xcE246eEa10988C495B4A90a905Ee9237a0f91543);
    WrappedToken public wrappedToken;

    address user = 0x22f5413C075Ccd56D575A54763831C4c27A37Bdb;
    address bob = address(0xDCBA);

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("mainnet"));

        wrappedToken = new WrappedToken(address(vcx));
    }

    function test__init() public {
        // little redundant -- i know
        assertFalse(address(vcx) == address(wrappedToken));
    }

    function test__wrap() public {
        vm.prank(user);
        vcx.approve(address(wrappedToken), 100e18);

        vm.prank(user);
        wrappedToken.wrap(50e18);

        assertEq(vcx.balanceOf(address(wrappedToken)), 50e18);
        assertEq(wrappedToken.balanceOf(user), 50e18);

        vm.prank(user);
        wrappedToken.wrap(bob, 50e18);

        assertEq(vcx.balanceOf(address(wrappedToken)), 100e18);
        assertEq(wrappedToken.balanceOf(user), 50e18);
        assertEq(wrappedToken.balanceOf(bob), 50e18);
    }

    function testFail__wrap_not_approved() public {
        vm.prank(user);
        wrappedToken.wrap(50e18);
    }

    function testFail__wrap_balance_insufficient() public {
        vm.prank(bob);
        vcx.approve(address(wrappedToken), 100e18);

        vm.prank(bob);
        wrappedToken.wrap(100e18);
    }

    function test__unwrap() public {
        vm.prank(user);
        vcx.approve(address(wrappedToken), 100e18);

        vm.prank(user);
        wrappedToken.wrap(100e18);

        vm.prank(user);
        wrappedToken.unwrap(50e18);

        assertEq(vcx.balanceOf(address(wrappedToken)), 50e18);
        assertEq(wrappedToken.balanceOf(user), 50e18);

        vm.prank(user);
        wrappedToken.unwrap(bob, 50e18);

        assertEq(vcx.balanceOf(address(wrappedToken)), 0);
        assertEq(wrappedToken.balanceOf(user), 0);
        assertEq(vcx.balanceOf(bob), 50e18);
    }
}
