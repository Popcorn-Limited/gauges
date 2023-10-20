# Popcorn gauge contracts

Foundry repo for contracts used by Popcorn's gauge system.

## Deployment

1. `DeployBoostV2`
2. update VOTING_ESCROW constant value in DelegationProxy.vy and execute `DeployDelegationProxy`
3. `Deploy`
4. `ActivateTokenAdmin`
5. `DeployGauges`

## Installation

To install with [Foundry](https://github.com/gakonst/foundry):

```
forge install timeless-fi/gauge-foundry
```

## Local development

This project uses [Foundry](https://github.com/gakonst/foundry) as the development framework. It also requires Vyper to be installed.

### Dependencies

```
forge install
```

### Compilation

```
forge build
```

### Testing

```
forge test
```

### Contract deployment

Please create a `.env` file before deployment. An example can be found in `.env.example`.

#### Dryrun

```
forge script script/Deploy.s.sol -f [network]
```

### Live

```
forge script script/Deploy.s.sol -f [network] --verify --broadcast
```

## Known issues

### Gauge stakers can abuse their boost after `tokenless_production` is updated

After the `tokenless_production` value has been updated in `PopcornLiquidityGauge`, some stakers may see their staking weight decrease once `_update_liquidity_limit()` is called, but this may not happen if the staker doesn't call the gauge contract (e.g. deposit, withdraw, claim rewards), which gives them outsized staking weights.


# Guide: Deploying POP 2.0

## OptionsToken Repo

First, create the .env file and specify:
- POPCORN & WETH Token address
- RPC URLs
- ETHERSCAN_KEY for contract verification
- VERSION (the version that you use here, you'll also have to use for the rest of the deployment.)
- OWNER
- TREASURY (receives the WETH from the oPOP redemptions)

see `.env.example`

### 1. Deploying the Balancer Pool

Deploy using the `DeployBalancerPool.s.sol` script: https://github.com/Popcorn-Limited/options-token/blob/main/script/DeployBalancerPool.s.sol

First, adjust:
- the pool factory address
    - [mainnet](https://etherscan.io/address/0xA5bf2ddF098bb0Ef6d120C98217dD6B141c74EE0)
    - [arbitrum](https://arbiscan.io/address/0x8df6EfEc5547e31B0eb7d1291B511FF8a2bf987c)

The pool deployment will fail, if token A > token B. For mainnet this is not an issue because WETH address < POP address. Not sure whether that's also true for Arbitrum.

```shell
forge script script/DeployBalancerPool.s.sol --keystores ~/path/to/keystore/file --password "<keystore-password>" --rpc-url $RPC_URL_GOERLI --broadcast --verify --delay 30
```

### 2. Initializing the Balancer Pool

Deploy using the `InitBalancerPool.s.sol` script: https://github.com/Popcorn-Limited/options-token/blob/main/script/InitBalancerPool.s.sol

Adjust the input amounts on line 19 for WETH and 20 for POP. Decide a $ amount you want to put in and make sure that 20% of this value comes from the WETH-amount and 80% from the POP-amount.

```shell
forge script script/InitBalancerPool.s.sol --keystores ~/path/to/keystore/file --password "<keystore-password>" --rpc-url $RPC_URL_GOERLI --broadcast --verify --delay 30
```

### 3. Deploy OptionsToken

adjust the .env file again:
- add the balancer pool address
- specify the oracle configuration, e.g.
    - ORACLE_MULTIPLIER = 5000 (50%)
    - ORACLE_SECS = 43200 (12 hour oracle window)
    - ORACLE_AGO = 0 (most recent 12 hours)
    - ORACLE_MIN_PRICE = 1e9 (1 Gwei minimum price)
- specify the OptionToken's name and symbol and the payment address (WETH)

```shell
forge script script/Deploy.s.sol --keystores ~/path/to/keystore/file --password "<keystore-password>" --rpc-url $RPC_URL_GOERLI --broadcast --verify --delay 30
```

## Gauges

First, create the .env file and specify:
- VERSION (same as the one used for OptionsToken)
- ADMIN (address of the deployer, should be same as the one used for OptionsToken)
- VAULT_REGISTRY
- LOCK_TOKEN (POP)

The deployment here is a little tricky because we have vyper files with three different versions:
- BoostV2.vy uses 0.3.3
- DelegationProxy.vy uses 0.2.15
- Rest uses 0.3.7

Each have to be deployed independently in an environment where the given vyper version's compiler is installed.

### BoostV2

```shell
forge script script/DeployBoostV2.s.sol --keystores ~/path/to/keystore/file --password "<keystore-password>" --rpc-url $RPC_URL_GOERLI --broadcast --verify --delay 30
```

### DelegationProxy

```shell
forge script script/DeployDelegationProxy.s.sol --keystores ~/path/to/keystore/file --password "<keystore-password>" --rpc-url $RPC_URL_GOERLI --broadcast --verify --delay 30
```

### Rest of the vePOP files

```shell
forge script script/Deploy.s.sol --keystores ~/path/to/keystore/file --password "<keystore-password>" --rpc-url $RPC_URL_GOERLI --broadcast --verify --delay 30
```

### Deploying Gauges

You can specify a list of vaults for which gauges should be deployed in the .env file:

`INITIAL_VAULTS=0x123,0x456,0x5678` and so on
The TokenAdmin must be activated for this to work. Activating the TokenAdmin will also start the oToken distribution.

Then you execute:

```shell
forge script script/DeployGauges.s.sol --keystores ~/path/to/keystore/file --password "<keystore-password>" --rpc-url $RPC_URL_GOERLI --broadcast --verify --delay 30
```

That'll create a gauge for all the vaults you specified and set the `tokenless_production` to 20.

### Activate Token Admin

This will start the oPOP distribution.

```shell
forge script script/ActivateTokenAdmin.s.sol --keystores ~/path/to/keystore/file --password "<keystore-password>" --rpc-url $RPC_URL_GOERLI --broadcast
```
