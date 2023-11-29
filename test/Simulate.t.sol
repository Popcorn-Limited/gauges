// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.11;

import "forge-std/Test.sol";

import {IVaultRegistry, VaultMetadata} from "popcorn/src/interfaces/vault/IVaultRegistry.sol";
import {VaultRegistry} from "popcorn/src/vault/VaultRegistry.sol";
import {MockERC4626, IERC4626, IERC20} from "popcorn/test/utils/mocks/MockERC4626.sol";

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

interface OToken {
    function exercise(
        uint256 amount,
        uint256 maxPaymentAmount,
        address recipient
    ) external;
}

interface VaultRouter {
    function depositAndStake(
        address vault,
        address gauge,
        uint256 assetAmount,
        address receiver
    ) external;
}

contract SimulateTest is Test {
    address admin = address(0x2C3B135cd7dc6C673b358BEF214843DAb3464278);

    IERC4626 vault = IERC4626(0x6cE9c05E159F8C4910490D8e8F7a63e95E6CEcAF);
    IERC20 asset = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    IERC20 lp = IERC20(0x577A7f7EE659Aa14Dc16FD384B3F8078E23F1920);
    IERC20 weth = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    OToken oVCX = OToken(0xaFa52E3860b4371ab9d8F08E801E9EA1027C0CA2);
    IERC20 vcx = IERC20(0xcE246eEa10988C495B4A90a905Ee9237a0f91543);

    VaultRouter router =
        VaultRouter(0x8aed8Ea73044910760E8957B6c5b28Ac51f8f809);

    IVotingEscrow votingEscrow =
        IVotingEscrow(0x0aB4bC35Ef33089B9082Ca7BB8657D7c4E819a1A);
    IGaugeController gaugeController =
        IGaugeController(0xD57d8EEC36F0Ba7D8Fd693B9D97e02D8353EB1F4);
    TokenAdmin tokenAdmin =
        TokenAdmin(0x03d103c547B43b5a76df7e652BD0Bb61bE0BD70d);
    PopcornLiquidityGaugeFactory factory =
        PopcornLiquidityGaugeFactory(
            0x32a33CC9dC61352E70cb557927E5F9544ddb0a26
        );
    Minter minter = Minter(0x49f095B38eE6d8541758af51c509332e7793D4b0);

    function setUp() public {
        uint256 forkId = vm.createSelectFork(vm.rpcUrl("mainnet"));
        vm.selectFork(forkId);
    }

    function test_all_the_things() public {
        vm.startPrank(admin);

        // Activate TokenAdmin
        tokenAdmin.activate();

        // Add gauges
        gaugeController.add_type("Ethereum", 1);

        address[] memory vaults = new address[](1);
        vaults[0] = 0x759281a408A48bfe2029D259c23D7E848A7EA1bC;

        ILiquidityGauge[] memory gauges = new ILiquidityGauge[](vaults.length);
        for (uint256 i; i < vaults.length; ) {
            gauges[i] = ILiquidityGauge(factory.create(vaults[i], 1e18));

            gaugeController.add_gauge(address(gauges[i]), 0, 1);

            gauges[i].set_tokenless_production(20);

            unchecked {
                ++i;
            }
        }
        vm.stopPrank();

        // Lock VCX_LP
        deal(address(lp), admin, 1e18);

        vm.startPrank(admin);
        lp.approve(address(votingEscrow), 1e18);
        votingEscrow.create_lock(1e18, block.timestamp + 4 * 365);

        gaugeController.vote_for_many_gauge_weights(
            [
                address(gauges[0]),
                address(0),
                address(0),
                address(0),
                address(0),
                address(0),
                address(0),
                address(0)
            ],
            [
                uint256(10_000),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0)
            ]
        );
        vm.stopPrank();

        // Get Vault and Gauge
        deal(address(asset), admin, 1e18);

        vm.startPrank(admin);
        asset.approve(address(router), 1e18);
        router.depositAndStake(address(vault), address(gauges[0]), 1e18, admin);

        emit log_named_uint(
            "gauge bal",
            IERC20(address(gauges[0])).balanceOf(admin)
        );

        // Time jump
        vm.warp(1 days);

        // Claim
        address[] memory _gauges = new address[](gauges.length);
        _gauges[0] = address(gauges[0]);
        minter.mintMany(_gauges);

        emit log_named_uint("oVCX bal", IERC20(address(oVCX)).balanceOf(admin));
        vm.stopPrank();

        // Fund oVCX
        deal(address(vcx), address(oVCX), 1e18);

        // Exercise
        deal(address(weth), admin, 1e18);
        
        vm.startPrank(admin);
        weth.approve(address(oVCX), 1e18);

        oVCX.exercise(1e18, 1e18, admin);

        emit log_named_uint("VCX bal", vcx.balanceOf(admin));
        vm.stopPrank();
    }
}
