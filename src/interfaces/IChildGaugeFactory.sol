// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IChildGaugeFactory {
    function deploy_gauge(address vault) external returns (address);
    function set_voting_escrow(address _voting_escrow) external;
    function set_implementation(address _implementation) external;
    function commit_transfer_ownership(address _future_owner) external;
    function accept_transfer_ownership() external;
    function get_implementation() external view returns (address);
    function voting_escrow() external view returns (address);
    function owner() external view returns (address);
    function future_owner() external view returns (address);
    function get_gauge_count() external view returns (uint256);
    function is_valid_gauge() external view returns (bool);
    function mint(address gauge) external returns (uint256);
    function mint_many(address[] calldata gauges) external returns (uint256);
    function token() external view returns (address);
    function set_token(address _token) external;
    function rescue_token(address _token) external;
    function rescue_token(address _token, address recipient) external;
}
