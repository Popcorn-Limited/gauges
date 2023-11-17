pragma solidity >=0.8.0;
import {Test} from "forge-std/Test.sol";

import {IERC20} from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";

import {VCX} from "../src/VCX.sol";

contract VCXTest is Test {
    IERC20 public pop = IERC20(0xD0Cd466b34A24fcB2f87676278AF2005Ca8A78c4);
    VCX public vcx;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("mainnet"));

        vcx = new VCX(address(this), "VCX", "VCX");
    
        vcx.setEndOfMigrationTs(block.timestamp + 10_000);
    }

    function test_migrate() public {
        // Largest POP holder
        address user = 0x93A32401D3E1425AD7b3E118816A1B900E714d18;
        uint initialPopBalance = pop.balanceOf(user);
        vm.startPrank(user);
        pop.approve(address(vcx), 1e18);

        vcx.migrate(user, 1e18);
        vm.stopPrank();

        assertEq(pop.balanceOf(address(vcx)), 1e18);
        assertEq(vcx.balanceOf(user), 10e18);
        assertEq(pop.balanceOf(user), initialPopBalance - 1e18);
    }

    function test_canNotMigrateAfterEnd() public {
        vcx.setEndOfMigrationTs(block.timestamp - 1);

        vm.expectRevert("CLOSED");
        vcx.migrate(address(this), 1e18);
    }
}