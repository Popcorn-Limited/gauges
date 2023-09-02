// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.11;

import "forge-std/Test.sol";

import {IVaultRegistry, VaultMetadata} from "popcorn/src/interfaces/vault/IVaultRegistry.sol";
import {VaultRegistry} from "popcorn/src/vault/VaultRegistry.sol";
import {MockERC4626} from "popcorn/test/utils/mocks/MockERC4626.sol";

import {IERC20Upgradeable} from "openzeppelin-contracts-upgradeable/interfaces/IERC20Upgradeable.sol";

import {Minter} from "../src/Minter.sol";
import {TokenAdmin} from "../src/TokenAdmin.sol";
import {VyperDeployer} from "../src/lib/VyperDeployer.sol";
import {TestERC20Mintable} from "./mocks/TestERC20Mintable.sol";
import {SmartWalletChecker} from "../src/SmartWalletChecker.sol";
import {IVotingEscrow} from "../src/interfaces/IVotingEscrow.sol";
import {IERC20Mintable} from "../src/interfaces/IERC20Mintable.sol";
import {ILiquidityGauge} from "../src/interfaces/ILiquidityGauge.sol";
import {IGaugeController} from "../src/interfaces/IGaugeController.sol";
import {IVotingEscrowDelegation} from "../src/interfaces/IVotingEscrowDelegation.sol";
import {PopcornLiquidityGaugeFactory} from "../src/PopcornLiquidityGaugeFactory.sol";

contract E2ETest is Test {
    address gaugeAdmin;
    address tokenAdminOwner;
    address votingEscrowAdmin;
    address veDelegationAdmin;
    address gaugeControllerAdmin;
    address smartWalletCheckerOwner;

    VyperDeployer vyperDeployer;

    MockERC4626 vault;
    Minter minter;
    VaultRegistry vaultRegistry;
    IERC20Mintable mockToken;
    IVotingEscrow votingEscrow;
    IGaugeController gaugeController;
    TokenAdmin tokenAdmin;
    IVotingEscrowDelegation veDelegation;
    PopcornLiquidityGaugeFactory factory;
    SmartWalletChecker smartWalletChecker;

    function setUp() public {
        // init accounts
        gaugeAdmin = makeAddr("gaugeAdmin");
        votingEscrowAdmin = makeAddr("votingEscrowAdmin");
        veDelegationAdmin = makeAddr("veDelegationAdmin");
        gaugeControllerAdmin = makeAddr("gaugeControllerAdmin");
        smartWalletCheckerOwner = makeAddr("smartWalletCheckerOwner");

        // create vyper contract deployer
        vyperDeployer = new VyperDeployer();

        // deploy contracts
        mockToken = IERC20Mintable(address(new TestERC20Mintable()));
        address minterAddress = computeCreateAddress(address(this), 4);
        tokenAdmin = new TokenAdmin(mockToken, Minter(minterAddress), tokenAdminOwner);
        votingEscrow = IVotingEscrow(
            vyperDeployer.deployContract(
                "VotingEscrow", abi.encode(mockToken, "Popcorn Voting Escrow", "veTIT", votingEscrowAdmin)
            )
        );
        gaugeController = IGaugeController(
            vyperDeployer.deployContract("GaugeController", abi.encode(votingEscrow, gaugeControllerAdmin))
        );
        minter = new Minter(tokenAdmin, gaugeController);
        assert(address(minter) == minterAddress);
        veDelegation = IVotingEscrowDelegation(
            vyperDeployer.deployContract(
                "VotingEscrowDelegation",
                abi.encode(votingEscrow, "Popcorn VE-Delegation", "veTIT-BOOST", "", veDelegationAdmin)
            )
        );
        ILiquidityGauge liquidityGaugeTemplate =
            ILiquidityGauge(vyperDeployer.deployContract("PopcornLiquidityGauge", abi.encode(minter)));

        // create vault registry because the gauge factory needs it to check whether a given vault is valid
        vaultRegistry = new VaultRegistry(address(this));
        vault = new MockERC4626();
        vault.initialize(IERC20Upgradeable(address(new TestERC20Mintable())), "vault", "V");
        address[8] memory swaps;
        VaultMetadata memory metadata = VaultMetadata({
            vault: address(vault),
            staking: address(0),
            creator: address(this),
            metadataCID: "",
            swapTokenAddresses: swaps,
            swapAddress: address(0),
            exchange: 0
        });
        vaultRegistry.registerVault(metadata);
        // mint vault shares to deposit into the gauge
        deal(address(vault), address(this), 1e18); // same amount as the liquidity in original tests

        factory = new PopcornLiquidityGaugeFactory(liquidityGaugeTemplate, gaugeAdmin, address(veDelegation), IVaultRegistry(address(vaultRegistry)));

        // activate inflation rewards
        vm.prank(tokenAdminOwner);
        tokenAdmin.activate();

        // add gauge type
        vm.prank(gaugeControllerAdmin);
        gaugeController.add_type("Ethereum", 1);

        // set smart wallet checker
        address[] memory initialAllowedAddresses = new address[](1);
        initialAllowedAddresses[0] = address(this);
        smartWalletChecker = new SmartWalletChecker(smartWalletCheckerOwner, initialAllowedAddresses);
        vm.startPrank(votingEscrowAdmin);
        votingEscrow.commit_smart_wallet_checker(address(smartWalletChecker));
        votingEscrow.apply_smart_wallet_checker();
        vm.stopPrank();
    }

    /**
     * Gauge creation/kill tests
     */

    function test_createGauge() external {
        // create gauge
        ILiquidityGauge gauge = ILiquidityGauge(factory.create(address(vault), 1 ether));

        // verify gauge state
        assertEq(gauge.is_killed(), false, "Gauge killed at creation");
    }

    function test_onlyAdminCanCreateGauge() external {
        vm.startPrank(vm.addr(1));
        vm.expectRevert("UNAUTHORIZED");
        factory.create(address(vault), 1 ether);
    }

    function test_adminKillGauge() external {
        // create gauge
        ILiquidityGauge gauge = ILiquidityGauge(factory.create(address(vault), 1 ether));

        // kill gauge
        vm.prank(gaugeAdmin);
        gauge.killGauge();

        // verify gauge state
        assertEq(gauge.is_killed(), true, "Gauge hasn't been killed");
    }

    function test_adminUnkillKilledGauge() external {
        // create gauge
        ILiquidityGauge gauge = ILiquidityGauge(factory.create(address(vault), 1 ether));

        // kill gauge
        vm.prank(gaugeAdmin);
        gauge.killGauge();

        // unkill gauge
        vm.prank(gaugeAdmin);
        gauge.unkillGauge();

        // verify gauge state
        assertEq(gauge.is_killed(), false, "Gauge hasn't been unkilled");
    }

    /**
     * Contract ownership tests
     */

    function test_ownership_gaugeController() external {
        address newOwner = makeAddr("newOwner");

        // transfer ownership
        vm.prank(gaugeControllerAdmin);
        gaugeController.change_pending_admin(newOwner);
        assertEq(gaugeController.admin(), gaugeControllerAdmin, "change_pending_admin updated admin");

        // claim ownership
        vm.prank(newOwner);
        gaugeController.claim_admin();
        assertEq(gaugeController.admin(), newOwner, "claim_admin didn't update admin");
    }

    function test_ownership_gaugeController_randoCannotChangePendingAdmin(address rando) external {
        vm.assume(rando != gaugeControllerAdmin);

        address newOwner = makeAddr("newOwner");

        // transfer ownership
        vm.prank(rando);
        vm.expectRevert();
        gaugeController.change_pending_admin(newOwner);
    }

    function test_ownership_gaugeController_randoCannotClaimAdmin(address rando) external {
        address newOwner = makeAddr("newOwner");
        vm.assume(rando != newOwner);

        // transfer ownership
        vm.prank(gaugeControllerAdmin);
        gaugeController.change_pending_admin(newOwner);

        // claim ownership
        vm.prank(rando);
        vm.expectRevert();
        gaugeController.claim_admin();
    }

    function test_ownership_gauge() external {
        address newOwner = makeAddr("newOwner");

        // create gauge
        ILiquidityGauge gauge = ILiquidityGauge(factory.create(address(vault), 1 ether));

        // transfer ownership
        vm.prank(gaugeAdmin);
        gauge.change_pending_admin(newOwner);
        assertEq(gauge.admin(), gaugeAdmin, "change_pending_admin updated admin");

        // claim ownership
        vm.prank(newOwner);
        gauge.claim_admin();
        assertEq(gauge.admin(), newOwner, "claim_admin didn't update admin");
    }

    function test_ownership_gauge_randoCannotChangePendingAdmin(address rando) external {
        vm.assume(rando != gaugeAdmin);

        address newOwner = makeAddr("newOwner");

        // create gauge
        ILiquidityGauge gauge = ILiquidityGauge(factory.create(address(vault), 1 ether));

        // transfer ownership
        vm.prank(rando);
        vm.expectRevert();
        gauge.change_pending_admin(newOwner);
    }

    function test_ownership_gauge_randoCannotClaimAdmin(address rando) external {
        address newOwner = makeAddr("newOwner");
        vm.assume(rando != newOwner);

        // create gauge
        ILiquidityGauge gauge = ILiquidityGauge(factory.create(address(vault), 1 ether));

        // transfer ownership
        vm.prank(gaugeAdmin);
        gauge.change_pending_admin(newOwner);

        // claim ownership
        vm.prank(rando);
        vm.expectRevert();
        gauge.claim_admin();
    }

    function test_ownership_votingEscrow() external {
        address newOwner = makeAddr("newOwner");

        // transfer ownership
        vm.prank(votingEscrowAdmin);
        votingEscrow.change_pending_admin(newOwner);
        assertEq(votingEscrow.admin(), votingEscrowAdmin, "change_pending_admin updated admin");

        // claim ownership
        vm.prank(newOwner);
        votingEscrow.claim_admin();
        assertEq(votingEscrow.admin(), newOwner, "claim_admin didn't update admin");
    }

    function test_ownership_votingEscrow_randoCannotChangePendingAdmin(address rando) external {
        vm.assume(rando != votingEscrowAdmin);

        address newOwner = makeAddr("newOwner");

        // transfer ownership
        vm.prank(rando);
        vm.expectRevert();
        votingEscrow.change_pending_admin(newOwner);
    }

    function test_ownership_votingEscrow_randoCannotClaimAdmin(address rando) external {
        address newOwner = makeAddr("newOwner");
        vm.assume(rando != newOwner);

        // transfer ownership
        vm.prank(votingEscrowAdmin);
        votingEscrow.change_pending_admin(newOwner);

        // claim ownership
        vm.prank(rando);
        vm.expectRevert();
        votingEscrow.claim_admin();
    }

    function test_ownership_veDelegation() external {
        address newOwner = makeAddr("newOwner");

        // transfer ownership
        vm.prank(veDelegationAdmin);
        veDelegation.change_pending_admin(newOwner);
        assertEq(veDelegation.admin(), veDelegationAdmin, "change_pending_admin updated admin");

        // claim ownership
        vm.prank(newOwner);
        veDelegation.claim_admin();
        assertEq(veDelegation.admin(), newOwner, "claim_admin didn't update admin");
    }

    function test_ownership_veDelegation_randoCannotChangePendingAdmin(address rando) external {
        vm.assume(rando != veDelegationAdmin);

        address newOwner = makeAddr("newOwner");

        // transfer ownership
        vm.prank(rando);
        vm.expectRevert();
        veDelegation.change_pending_admin(newOwner);
    }

    function test_ownership_veDelegation_randoCannotClaimAdmin(address rando) external {
        address newOwner = makeAddr("newOwner");
        vm.assume(rando != newOwner);

        // transfer ownership
        vm.prank(veDelegationAdmin);
        veDelegation.change_pending_admin(newOwner);

        // claim ownership
        vm.prank(rando);
        vm.expectRevert();
        veDelegation.claim_admin();
    }

    /**
     * Gauge interaction tests
     */

    function test_gauge_stakeRewards() external {
        // create gauge
        ILiquidityGauge gauge = ILiquidityGauge(factory.create(address(vault), 1 ether));

        // approve gauge
        vm.prank(gaugeControllerAdmin);
        gaugeController.add_gauge(address(gauge), 0, 1);

        // lock tokens in voting escrow
        mockToken.mint(address(this), 1 ether);
        mockToken.approve(address(votingEscrow), type(uint256).max);
        votingEscrow.create_lock(1 ether, block.timestamp + 200 weeks);

        // stake liquidity
        vault.approve(address(gauge), type(uint256).max);
        uint256 amount = vault.balanceOf(address(this));
        gauge.deposit(1);

        // wait
        skip(4 weeks);

        // claim rewards
        uint256 minted = minter.mint(address(gauge));

        // check balance
        uint256 expectedAmount = tokenAdmin.INITIAL_RATE() * (3 weeks); // first week has no rewards
        assertApproxEqRel(minted, expectedAmount, 1e12, "minted incorrect");
        assertApproxEqRel(mockToken.balanceOf(address(this)), expectedAmount, 1e12, "balance incorrect");
    }

    function test_gauge_stakeAndUnstake() external {
        // create gauge
        ILiquidityGauge gauge = ILiquidityGauge(factory.create(address(vault), 1 ether));

        // approve gauge
        vm.prank(gaugeControllerAdmin);
        gaugeController.add_gauge(address(gauge), 0, 1);

        // stake liquidity
        vault.approve(address(gauge), type(uint256).max);
        uint256 amount = vault.balanceOf(address(this));
        gauge.deposit(amount);

        // check balances
        assertEq(vault.balanceOf(address(this)), 0, "user still has LP tokens after deposit");
        assertEq(vault.balanceOf(address(gauge)), amount, "LP tokens didn't get transferred to gauge");
        assertEq(gauge.balanceOf(address(this)), amount, "user didn't get gauge tokens");

        // withdraw liquidity
        gauge.withdraw(amount);

        // check balances
        assertEq(vault.balanceOf(address(this)), amount, "user didn't receive LP tokens after withdraw");
        assertEq(vault.balanceOf(address(gauge)), 0, "gauge still has LP tokens after withdraw");
        assertEq(gauge.balanceOf(address(this)), 0, "user still has gauge tokens after withdraw");
    }

    function test_votingEscrow_earlyWithdrawal() external {
        // lock tokens in voting escrow
        mockToken.mint(address(this), 1 ether);
        mockToken.approve(address(votingEscrow), type(uint256).max);
        votingEscrow.create_lock(1 ether, block.timestamp + 200 weeks);

        skip(199 weeks);

        votingEscrow.withdraw();
        assertEq(mockToken.balanceOf(address(this)), 0.75 ether, "should get a penalty for withdrawing early");
    }

    function test_votingEscrow_orderlyWithdrawal() external {
        // lock tokens in voting escrow
        mockToken.mint(address(this), 1 ether);
        mockToken.approve(address(votingEscrow), type(uint256).max);
        votingEscrow.create_lock(1 ether, block.timestamp + 200 weeks);

        skip(200 weeks + 1);

        votingEscrow.withdraw();
        assertEq(mockToken.balanceOf(address(this)), 1 ether, "should get a penalty for withdrawing early");
    }

    function test_gauge_onePerVault() external {
        // test whether there can only be one gauge per vault
        ILiquidityGauge(factory.create(address(vault), 1 ether));

        vm.expectRevert();
        ILiquidityGauge(factory.create(address(vault), 1 ether));
    }

    function test_votingEscrow_maxTime() external {
        mockToken.mint(address(this), 1 ether);
        mockToken.approve(address(votingEscrow), type(uint256).max);
        votingEscrow.create_lock(1 ether, block.timestamp + 4 * 365 * 1 days);

        uint bal = votingEscrow.balanceOf(address(this));

        assertApproxEqRel(bal, 1 ether, 5e15, "doesn't provide max balance");
    }

    function test_votingEscrow_cannotExceedMaxTime() external {
        mockToken.mint(address(this), 1 ether);
        mockToken.approve(address(votingEscrow), type(uint256).max);
        vm.expectRevert("Voting lock can be 4 year max");
        votingEscrow.create_lock(1 ether, block.timestamp + 4 * 365 * 1 days + 1 weeks);
    }
}
