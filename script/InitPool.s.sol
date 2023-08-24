pragma solidity ^0.8.13;

import "forge-std/Script.sol";

interface IERC20 {
    function approve(address to, uint amount) external returns (bool);
}

enum JoinKind {
    INIT,
    EXACT_TOKENS_IN_FOR_BPT_OUT,
    TOKEN_IN_FOR_EXACT_BPT_OUT,
    ALL_TOKENS_IN_FOR_EXACT_BPT_OUT
}

struct JoinPoolRequest {
    address[] assets;
    uint256[] maxAmountsIn;
    bytes userData;
    bool fromInternalBalance;
}

struct FundManagement {
    address sender;
    bool fromInternalBalance;
    address payable recipient;
    bool toInternalBalance;
}

enum SwapKind { GIVEN_IN, GIVEN_OUT }

struct SingleSwap {
    bytes32 poolId;
    SwapKind kind;
    address assetIn;
    address assetOut;
    uint256 amount;
    bytes userData;
 }

interface Vault {
    function joinPool(bytes32 poolId, address sender, address recipient, JoinPoolRequest memory request) external;        
    function swap(SingleSwap memory singleSwap, FundManagement memory funds, uint256 limit, uint256 deadline) external returns (uint256 amountCalculated);
}

contract SendTokensScript is Script {
    function run() public {
        address admin = vm.envAddress("ADMIN");
        vm.startBroadcast(admin);

        Vault vault = Vault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
        bytes32 poolId = vm.envBytes32("POOL_ID");
        IERC20 pop = IERC20(vm.envAddress("POP"));
        IERC20 weth = IERC20(vm.envAddress("WETH"));
        
        // // pop.approve(address(vault), 4000e18);
        // weth.approve(address(vault), 1e18);

        // SingleSwap memory swap = SingleSwap({
        //     poolId: poolId,
        //     kind: SwapKind.GIVEN_IN,
        //     assetIn: address(weth),
        //     assetOut: address(pop),
        //     amount: 1e18,
        //     userData: ""
        // });

        // FundManagement memory funds = FundManagement({
        //     sender: admin,
        //     fromInternalBalance: false,
        //     recipient: payable(admin),
        //     toInternalBalance: false
        // });

        // vault.swap(swap, funds, block.timestamp, 1e18);

        address[] memory _assets = new address[](2);
        _assets[0] = address(weth);
        _assets[1] = address(pop);

        uint[] memory _amounts = new uint[](2);
        _amounts[0] = 1000e18;
        _amounts[1] = 4000e18;

        JoinPoolRequest memory request = JoinPoolRequest({
            assets: _assets,
            maxAmountsIn: _amounts,
            userData: abi.encode(JoinKind.INIT, _amounts),
            fromInternalBalance: false
        });

        vault.joinPool(poolId, admin, admin, request);
    }
}


