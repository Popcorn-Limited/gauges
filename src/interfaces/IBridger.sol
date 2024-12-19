// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBridger {
    function check(address toCheck) external view returns (bool);
    function cost() external view returns (uint256);
    function bridge(address token, address dest, uint256 amount) external payable;
}
