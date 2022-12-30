// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.11;

import {BunniHub, BunniKey} from "bunni/src/BunniHub.sol";
import {IBunniHub} from "bunni/src/interfaces/IBunniHub.sol";
import {UniswapDeployer} from "bunni/src/tests/lib/UniswapDeployer.sol";
import {SwapRouter} from "bunni/lib/v3-periphery/contracts/SwapRouter.sol";
import {TickMath} from "bunni/lib/v3-core/contracts/libraries/TickMath.sol";
import {ISwapRouter} from "bunni/lib/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {IUniswapV3Pool} from "bunni/lib/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IUniswapV3Factory} from "bunni/lib/v3-core/contracts/interfaces/IUniswapV3Factory.sol";

import "forge-std/Test.sol";

import {WETH} from "solmate/tokens/WETH.sol";

import {UniswapPoorOracle} from "uniswap-poor-oracle/UniswapPoorOracle.sol";

import {Minter} from "../src/Minter.sol";
import {TokenAdmin} from "../src/TokenAdmin.sol";
import {VyperDeployer} from "../src/lib/VyperDeployer.sol";
import {TestERC20Mintable} from "./mocks/TestERC20Mintable.sol";
import {SmartWalletChecker} from "../src/SmartWalletChecker.sol";
import {IVotingEscrow} from "../src/interfaces/IVotingEscrow.sol";
import {IERC20Mintable} from "../src/interfaces/IERC20Mintable.sol";
import {ILiquidityGauge} from "../src/interfaces/ILiquidityGauge.sol";
import {IGaugeController} from "../src/interfaces/IGaugeController.sol";
import {TimelessLiquidityGaugeFactory} from "../src/TimelessLiquidityGaugeFactory.sol";

contract E2ETest is Test, UniswapDeployer {
    uint24 constant FEE = 500;
    uint256 constant IN_RANGE_THRESHOLD = 5e17;
    uint256 constant RECORDING_MIN_LENGTH = 1 hours;
    uint256 constant RECORDING_MAX_LENGTH = 1 hours + 30 minutes;
    int24 constant TICK_LOWER = -10;
    int24 constant TICK_UPPER = 10;

    address gaugeAdmin;
    address bunniHubOwner;
    address tokenAdminOwner;
    address votingEscrowAdmin;
    address veDelegationAdmin;
    address gaugeControllerAdmin;
    address smartWalletCheckerOwner;

    VyperDeployer vyperDeployer;

    WETH weth;
    BunniKey key;
    Minter minter;
    BunniHub bunniHub;
    SwapRouter router;
    IUniswapV3Pool pool;
    TokenAdmin tokenAdmin;
    TestERC20Mintable tokenA;
    TestERC20Mintable tokenB;
    UniswapPoorOracle oracle;
    IERC20Mintable mockToken;
    IVotingEscrow votingEscrow;
    IUniswapV3Factory uniswapFactory;
    IGaugeController gaugeController;
    TimelessLiquidityGaugeFactory factory;
    SmartWalletChecker smartWalletChecker;

    function setUp() public {
        // init accounts
        gaugeAdmin = makeAddr("gaugeAdmin");
        bunniHubOwner = makeAddr("bunniHubOwner");
        tokenAdminOwner = makeAddr("tokenAdminOwner");
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
                "VotingEscrow", abi.encode(mockToken, "Timeless Voting Escrow", "veTIT", votingEscrowAdmin)
            )
        );
        gaugeController = IGaugeController(
            vyperDeployer.deployContract("GaugeController", abi.encode(votingEscrow, gaugeControllerAdmin))
        );
        minter = new Minter(tokenAdmin, gaugeController);
        assert(address(minter) == minterAddress);
        address veDelegation = vyperDeployer.deployContract(
            "VotingEscrowDelegation",
            abi.encode(votingEscrow, "Timeless VE-Delegation", "veTIT-BOOST", "", veDelegationAdmin)
        );
        oracle = new UniswapPoorOracle(IN_RANGE_THRESHOLD, RECORDING_MIN_LENGTH, RECORDING_MAX_LENGTH);
        ILiquidityGauge liquidityGaugeTemplate =
            ILiquidityGauge(vyperDeployer.deployContract("TimelessLiquidityGauge", abi.encode(minter, oracle)));
        uniswapFactory = IUniswapV3Factory(deployUniswapV3Factory());
        bunniHub = new BunniHub(uniswapFactory, bunniHubOwner, 0);
        factory = new TimelessLiquidityGaugeFactory(liquidityGaugeTemplate, gaugeAdmin, veDelegation, bunniHub);
        weth = new WETH();
        router = new SwapRouter(address(uniswapFactory), address(weth));

        // deploy mock uniswap pool
        tokenA = new TestERC20Mintable();
        tokenB = new TestERC20Mintable();
        pool = IUniswapV3Pool(uniswapFactory.createPool(address(tokenA), address(tokenB), FEE));
        pool.initialize(TickMath.getSqrtRatioAtTick(0));
        vm.label(address(pool), "UniswapV3Pool");
        key = BunniKey({pool: pool, tickLower: TICK_LOWER, tickUpper: TICK_UPPER});
        bunniHub.deployBunniToken(key);

        // token approvals
        tokenA.approve(address(router), type(uint256).max);
        tokenA.approve(address(bunniHub), type(uint256).max);
        tokenB.approve(address(router), type(uint256).max);
        tokenB.approve(address(bunniHub), type(uint256).max);

        // provide liquidity
        tokenA.mint(address(this), 1e18);
        tokenB.mint(address(this), 1e18);
        bunniHub.deposit(
            IBunniHub.DepositParams({
                key: key,
                amount0Desired: 1e18,
                amount1Desired: 1e18,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp,
                recipient: address(this)
            })
        );

        // activate inflation rewards
        vm.prank(tokenAdminOwner);
        tokenAdmin.activate();

        // set smart wallet checker
        address[] memory initialAllowedAddresses = new address[](0);
        smartWalletChecker = new SmartWalletChecker(smartWalletCheckerOwner, initialAllowedAddresses);
        vm.startPrank(votingEscrowAdmin);
        votingEscrow.commit_smart_wallet_checker(address(smartWalletChecker));
        votingEscrow.apply_smart_wallet_checker();
        vm.stopPrank();
    }

    function test_createGauge() external {
        // create gauge
        ILiquidityGauge gauge = ILiquidityGauge(factory.create(key, 1 ether));

        // verify gauge state
        assertEq(gauge.is_killed(), false, "Gauge killed at creation");
    }

    function test_killOutOfRangeGauge() external {
        // create new position to initialize tickLower in the pool
        int24 tickLower = 100;
        int24 tickUpper = 1000;
        tokenA.mint(address(this), 1e18);
        tokenB.mint(address(this), 1e18);
        BunniKey memory k = BunniKey({pool: pool, tickLower: tickLower, tickUpper: tickUpper});
        bunniHub.deployBunniToken(k);
        bunniHub.deposit(
            IBunniHub.DepositParams({
                key: k,
                amount0Desired: 1e18,
                amount1Desired: 1e18,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp,
                recipient: address(this)
            })
        );

        // create gauge for out of range position
        ILiquidityGauge gauge = ILiquidityGauge(factory.create(k, 1 ether));

        // record
        oracle.startRecording(address(pool), 100, tickUpper);
        skip(RECORDING_MIN_LENGTH);
        UniswapPoorOracle.PositionState state = oracle.finishRecording(address(pool), 100, tickUpper);
        assertEq(uint256(state), uint256(UniswapPoorOracle.PositionState.OUT_OF_RANGE), "State not OUT_OF_RANGE");

        // verify gauge state
        assertEq(gauge.is_killed(), true, "Out-of-range gauge hasn't been killed");
    }

    function test_reviveInRangeGauge() external {
        // create gauge
        ILiquidityGauge gauge = ILiquidityGauge(factory.create(key, 1 ether));

        // make swap to move the price out of range
        uint256 amountIn = 1e20;
        tokenA.mint(address(this), amountIn);
        ISwapRouter.ExactInputSingleParams memory swapParams = ISwapRouter.ExactInputSingleParams({
            tokenIn: address(tokenA),
            tokenOut: address(tokenB),
            fee: FEE,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: amountIn,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });
        router.exactInputSingle(swapParams);
        (, int24 tick,,,,,) = pool.slot0();
        assert(tick > TICK_UPPER || tick < TICK_LOWER);

        // record
        oracle.startRecording(address(pool), TICK_LOWER, TICK_UPPER);
        skip(RECORDING_MIN_LENGTH);
        UniswapPoorOracle.PositionState state = oracle.finishRecording(address(pool), TICK_LOWER, TICK_UPPER);
        assertEq(uint256(state), uint256(UniswapPoorOracle.PositionState.OUT_OF_RANGE), "State not OUT_OF_RANGE");

        // verify gauge state
        assertEq(gauge.is_killed(), true, "Out-of-range gauge hasn't been killed");

        // make swap to move the price back into range
        swapParams = ISwapRouter.ExactInputSingleParams({
            tokenIn: address(tokenB),
            tokenOut: address(tokenA),
            fee: FEE,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: tokenB.balanceOf(address(this)),
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });
        router.exactInputSingle(swapParams);
        (, tick,,,,,) = pool.slot0();
        assert(tick <= TICK_UPPER && tick >= TICK_LOWER);

        // record
        oracle.startRecording(address(pool), TICK_LOWER, TICK_UPPER);
        skip(RECORDING_MIN_LENGTH);
        state = oracle.finishRecording(address(pool), TICK_LOWER, TICK_UPPER);
        assertEq(uint256(state), uint256(UniswapPoorOracle.PositionState.IN_RANGE), "State not IN_RANGE");

        // verify gauge state
        assertEq(gauge.is_killed(), false, "In-range gauge hasn't been revived");
    }

    function test_adminKillGauge() external {
        // create gauge
        ILiquidityGauge gauge = ILiquidityGauge(factory.create(key, 1 ether));

        // kill gauge
        vm.prank(gaugeAdmin);
        gauge.killGauge();

        // verify gauge state
        assertEq(gauge.is_killed(), true, "Gauge hasn't been killed");
    }

    function test_adminUnkillKilledGauge() external {
        // create gauge
        ILiquidityGauge gauge = ILiquidityGauge(factory.create(key, 1 ether));

        // kill gauge
        vm.prank(gaugeAdmin);
        gauge.killGauge();

        // unkill gauge
        vm.prank(gaugeAdmin);
        gauge.unkillGauge();

        // verify gauge state
        assertEq(gauge.is_killed(), false, "Gauge hasn't been unkilled");
    }

    function test_adminUnkillOutOfRangeGauge() external {
        // create gauge
        ILiquidityGauge gauge = ILiquidityGauge(factory.create(key, 1 ether));

        // make swap to move the price out of range
        uint256 amountIn = 1e20;
        tokenA.mint(address(this), amountIn);
        ISwapRouter.ExactInputSingleParams memory swapParams = ISwapRouter.ExactInputSingleParams({
            tokenIn: address(tokenA),
            tokenOut: address(tokenB),
            fee: FEE,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: amountIn,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });
        router.exactInputSingle(swapParams);
        (, int24 tick,,,,,) = pool.slot0();
        assert(tick > TICK_UPPER || tick < TICK_LOWER);

        // record
        oracle.startRecording(address(pool), TICK_LOWER, TICK_UPPER);
        skip(RECORDING_MIN_LENGTH);
        UniswapPoorOracle.PositionState state = oracle.finishRecording(address(pool), TICK_LOWER, TICK_UPPER);
        assertEq(uint256(state), uint256(UniswapPoorOracle.PositionState.OUT_OF_RANGE), "State not OUT_OF_RANGE");

        // verify gauge state
        assertEq(gauge.is_killed(), true, "Out-of-range gauge hasn't been killed");

        // admin unkill gauge
        vm.prank(gaugeAdmin);
        gauge.unkillGauge();

        // verify gauge state
        assertEq(gauge.is_killed(), false, "Gauge hasn't been unkilled");
    }
}
