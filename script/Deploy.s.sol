// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IVaultRegistry, VaultMetadata} from "popcorn/src/interfaces/vault/IVaultRegistry.sol";

import {Minter} from "../src/Minter.sol";
import {TokenAdmin} from "../src/TokenAdmin.sol";
import {CREATE3Script} from "./base/CREATE3Script.sol";
import {VyperDeployer} from "../src/lib/VyperDeployer.sol";
import {SmartWalletChecker} from "../src/SmartWalletChecker.sol";
import {IVotingEscrow} from "../src/interfaces/IVotingEscrow.sol";
import {IERC20Mintable} from "../src/interfaces/IERC20Mintable.sol";
import {ILiquidityGauge} from "../src/interfaces/ILiquidityGauge.sol";
import {IGaugeController} from "../src/interfaces/IGaugeController.sol";
import {PopcornLiquidityGaugeFactory} from "../src/PopcornLiquidityGaugeFactory.sol";
import "forge-std/Script.sol";

contract DeployScript is CREATE3Script, VyperDeployer {
    constructor() CREATE3Script(vm.envString("VERSION")) {}

    function run()
        public
        returns (
            Minter minter,
            TokenAdmin tokenAdmin,
            IVotingEscrow votingEscrow,
            IGaugeController gaugeController,
            PopcornLiquidityGaugeFactory factory,
            SmartWalletChecker smartWalletChecker
        )
    {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address admin = vm.envAddress("ADMIN");

        vm.startBroadcast(deployerPrivateKey);
        {
            IERC20Mintable rewardToken = IERC20Mintable(
                getCreate3Contract("OptionsToken")
            );

            console2.log("rewardToken ", address(rewardToken));
            console2.log("minter ", getCreate3Contract("Minter"));
            console2.log("admin ", address(admin));


            tokenAdmin = TokenAdmin(
                create3.deploy(
                    getCreate3ContractSalt("TokenAdmin"),
                    bytes.concat(
                        type(TokenAdmin).creationCode,
                        abi.encode(
                            rewardToken,
                            getCreate3Contract("Minter"),
                            admin
                        )
                    )
                )
            );
        }
        console2.log("tokenAdmin ", address(tokenAdmin));

        {
            address lockToken = vm.envAddress("BALANCER_POOL");
            votingEscrow = IVotingEscrow(
                create3.deploy(
                    getCreate3ContractSalt("VotingEscrow"),
                    bytes.concat(
                        compileContract("VotingEscrow"),
                        abi.encode(
                            lockToken,
                            "VaultCraft Voting Escrow",
                            "veVCX",
                            admin
                        )
                    )
                )
            );
        }
        console2.log("VotingEscrow");

        gaugeController = IGaugeController(
            create3.deploy(
                getCreate3ContractSalt("GaugeController"),
                bytes.concat(
                    compileContract("GaugeController"),
                    abi.encode(votingEscrow, admin)
                )
            )
        );
        console2.log("GaugeController");

        minter = Minter(
            create3.deploy(
                getCreate3ContractSalt("Minter"),
                bytes.concat(
                    type(Minter).creationCode,
                    abi.encode(tokenAdmin, gaugeController)
                )
            )
        );
        console2.log("Minter");

        address delegationProxy = getCreate3Contract("DelegationProxy");

        ILiquidityGauge liquidityGaugeTemplate = ILiquidityGauge(
            create3.deploy(
                getCreate3ContractSalt("PopcornLiquidityGauge"),
                bytes.concat(
                    compileContract("PopcornLiquidityGauge"),
                    abi.encode(minter, delegationProxy)
                )
            )
        );
        console2.log("PopcornLiquidityGauge");

        {
            IVaultRegistry vaultRegistry = IVaultRegistry(
                vm.envAddress("VAULT_REGISTRY")
            );
            factory = PopcornLiquidityGaugeFactory(
                create3.deploy(
                    getCreate3ContractSalt("PopcornLiquidityGaugeFactory2"),
                    bytes.concat(
                        type(PopcornLiquidityGaugeFactory).creationCode,
                        abi.encode(liquidityGaugeTemplate, admin, vaultRegistry)
                    )
                )
            );
        }
        console2.log("PopcornLiquidityGaugeFactory2");

        {
            address[] memory initialAllowlist = vm.envAddress(
                "INITIAL_ALLOWLIST",
                ","
            );
            smartWalletChecker = SmartWalletChecker(
                create3.deploy(
                    getCreate3ContractSalt("SmartWalletChecker"),
                    bytes.concat(
                        type(SmartWalletChecker).creationCode,
                        abi.encode(admin, initialAllowlist)
                    )
                )
            );
        }
        console2.log("SmartWalletChecker");

        // NOTE: The admin still needs to
        // - Activate inflation in tokenAdmin

        votingEscrow.commit_smart_wallet_checker(address(smartWalletChecker));
        votingEscrow.apply_smart_wallet_checker();

        vm.stopBroadcast();
    }
}
