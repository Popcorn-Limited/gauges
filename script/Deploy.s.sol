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
        address admin = vm.envAddress("ADMIN");
        vm.startBroadcast(admin);

        {
            IERC20Mintable rewardToken = IERC20Mintable(getCreate3Contract("OptionsToken"));
            tokenAdmin = TokenAdmin(
                create3.deploy(
                    getCreate3ContractSalt("TokenAdmin"),
                    bytes.concat(
                        type(TokenAdmin).creationCode, abi.encode(rewardToken, getCreate3Contract("Minter"), admin)
                    )
                )
            );
        }
        {
            address lockToken = vm.envAddress("LOCK_TOKEN");
            votingEscrow = IVotingEscrow(
                create3.deploy(
                    getCreate3ContractSalt("VotingEscrow"),
                    bytes.concat(
                        compileContract("VotingEscrow"), abi.encode(lockToken, "Popcorn Voting Escrow", "vePOP", admin)
                    )
                )
            );
        }
        gaugeController = IGaugeController(
            create3.deploy(
                getCreate3ContractSalt("GaugeController"),
                bytes.concat(compileContract("GaugeController"), abi.encode(votingEscrow, admin))
            )
        );
        minter = Minter(
            create3.deploy(
                getCreate3ContractSalt("Minter"),
                bytes.concat(type(Minter).creationCode, abi.encode(tokenAdmin, gaugeController))
            )
        );

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
        {
            IVaultRegistry vaultRegistry = IVaultRegistry(vm.envAddress("VAULT_REGISTRY"));
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
        {
            address[] memory initialAllowlist = vm.envAddress("INITIAL_ALLOWLIST", ",");
            smartWalletChecker = SmartWalletChecker(
                create3.deploy(
                    getCreate3ContractSalt("SmartWalletChecker"),
                    bytes.concat(type(SmartWalletChecker).creationCode, abi.encode(admin, initialAllowlist))
                )
            );
        }

        // NOTE: The admin still needs to
        // - Activate inflation in tokenAdmin

        votingEscrow.commit_smart_wallet_checker(address(smartWalletChecker));
        votingEscrow.apply_smart_wallet_checker();

        vm.stopBroadcast();
    }
}
