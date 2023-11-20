// SPDX-License-Identifier: GPL-3.0
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity ^0.8.0;

import {Owned} from "solmate/auth/Owned.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";

import {IMinter} from "./interfaces/IMinter.sol";
import {ITokenAdmin} from "./interfaces/ITokenAdmin.sol";
import {IERC20Mintable} from "./interfaces/IERC20Mintable.sol";

// solhint-disable not-rely-on-time

/**
 * @title Token Admin
 * @notice This contract holds all admin powers over the token passing through calls.
 *
 * In addition, calls to the mint function must respect the inflation schedule as defined in this contract.
 * As this contract is the only way to mint tokens this ensures that the maximum allowed supply is enforced
 * @dev This contract exists as a consequence of the gauge systems needing to know a fixed inflation schedule
 * in order to know how much tokens a gauge is allowed to mint. As this does not exist within the token itself
 * it is defined here, we must then wrap the token's minting functionality in order for this to be meaningful.
 */
contract TokenAdmin is ITokenAdmin, ReentrancyGuard, Owned {
    // Initial inflation rate of 2M tokens per week.
    uint256 public constant override INITIAL_RATE = (2_000_000 * 1e18) / uint256(1 weeks); // token has 18 decimals
    uint256 public constant override RATE_REDUCTION_TIME = 91 days; // 13 weeks (Nov 30 - Feb 29)
    uint256 public constant override RATE_REDUCTION_COEFFICIENT = 1.0271 * 1e18 ;
    uint256 public constant override RATE_DENOMINATOR = 1e18;

    IERC20Mintable private immutable _token;

    event MiningParametersUpdated(uint256 rate, uint256 supply);

    // Supply Variables
    uint256 private _miningEpoch;
    uint256 private _startEpochTime = type(uint256).max; // Sentinel value for contract not being activated
    uint256 private _startEpochSupply;
    uint256 private _rate;

    IMinter public immutable minter;

    constructor(IERC20Mintable token, IMinter minter_, address owner_) Owned(owner_) {
        _token = token;
        minter = minter_;
    }

    /**
     * @dev Returns the token being controlled.
     */
    function getToken() external view override returns (IERC20Mintable) {
        return _token;
    }

    /**
     * @notice Initiate token inflation schedule
     */
    function activate() external override nonReentrant onlyOwner {
        require(_startEpochTime == type(uint256).max, "Already activated");

        // initialise the relevant variables.
        _startEpochSupply = _token.totalSupply();
        _startEpochTime = block.timestamp;
        _rate = INITIAL_RATE;
        emit MiningParametersUpdated(INITIAL_RATE, _startEpochSupply);
    }

    /**
     * @notice Mint tokens subject to the defined inflation schedule
     */
    function mint(address to, uint256 amount) external override {
        require(msg.sender == address(minter), "NOT_MINTER");

        // Check if we've passed into a new epoch such that we should calculate available supply with a smaller rate.
        if (block.timestamp >= _startEpochTime + RATE_REDUCTION_TIME) {
            _updateMiningParameters();
        }

        require(_token.totalSupply() + amount <= _availableSupply(), "Mint amount exceeds remaining available supply");
        _token.mint(to, amount);
    }

    /**
     * @notice Returns the current epoch number.
     */
    function getMiningEpoch() external view returns (uint256) {
        return _miningEpoch;
    }

    /**
     * @notice Returns the start timestamp of the current epoch.
     */
    function getStartEpochTime() external view returns (uint256) {
        return _startEpochTime;
    }

    /**
     * @notice Returns the start timestamp of the next epoch.
     */
    function getFutureEpochTime() external view returns (uint256) {
        return _startEpochTime + RATE_REDUCTION_TIME;
    }

    /**
     * @notice Returns the available supply at the beginning of the current epoch.
     */
    function getStartEpochSupply() external view returns (uint256) {
        return _startEpochSupply;
    }

    /**
     * @notice Returns the current inflation rate of tokens per second
     */
    function getInflationRate() external view returns (uint256) {
        return _rate;
    }

    /**
     * @notice Maximum allowable number of tokens in existence (claimed or unclaimed)
     */
    function getAvailableSupply() external view returns (uint256) {
        return _availableSupply();
    }

    /**
     * @notice Get timestamp of the current mining epoch start while simultaneously updating mining parameters
     * @return Timestamp of the current epoch
     */
    function startEpochTimeWrite() external override returns (uint256) {
        return _startEpochTimeWrite();
    }

    /**
     * @notice Get timestamp of the next mining epoch start while simultaneously updating mining parameters
     * @return Timestamp of the next epoch
     */
    function futureEpochTimeWrite() external returns (uint256) {
        return _startEpochTimeWrite() + RATE_REDUCTION_TIME;
    }

    /**
     * @notice Update mining rate and supply at the start of the epoch
     * @dev Callable by any address, but only once per epoch
     * Total supply becomes slightly larger if this function is called late
     */
    function updateMiningParameters() external {
        require(block.timestamp >= _startEpochTime + RATE_REDUCTION_TIME, "Epoch has not finished yet");
        _updateMiningParameters();
    }

    /**
     * @notice How much supply is mintable from start timestamp till end timestamp
     * @param start Start of the time interval (timestamp)
     * @param end End of the time interval (timestamp)
     * @return Tokens mintable from `start` till `end`
     */
    function mintableInTimeframe(uint256 start, uint256 end) external view returns (uint256) {
        return _mintableInTimeframe(start, end);
    }

    // Internal functions

    /**
     * @notice Maximum allowable number of tokens in existence (claimed or unclaimed)
     */
    function _availableSupply() internal view returns (uint256) {
        uint256 newSupplyFromCurrentEpoch = (block.timestamp - _startEpochTime) * _rate;
        return _startEpochSupply + newSupplyFromCurrentEpoch;
    }

    /**
     * @notice Get timestamp of the current mining epoch start while simultaneously updating mining parameters
     * @return Timestamp of the current epoch
     */
    function _startEpochTimeWrite() internal returns (uint256) {
        uint256 startEpochTime = _startEpochTime;
        if (block.timestamp >= startEpochTime + RATE_REDUCTION_TIME) {
            _updateMiningParameters();
            return _startEpochTime;
        }
        return startEpochTime;
    }

    function _updateMiningParameters() internal {
        uint256 inflationRate = _rate;
        uint256 startEpochSupply = _startEpochSupply + (inflationRate * RATE_REDUCTION_TIME);
        inflationRate = inflationRate * RATE_DENOMINATOR / RATE_REDUCTION_COEFFICIENT;

        ++_miningEpoch;
        _startEpochTime += RATE_REDUCTION_TIME;
        _rate = inflationRate;
        _startEpochSupply = startEpochSupply;

        emit MiningParametersUpdated(inflationRate, startEpochSupply);
    }

    /**
     * @notice How much supply is mintable from start timestamp till end timestamp
     * @param start Start of the time interval (timestamp)
     * @param end End of the time interval (timestamp)
     * @return Tokens mintable from `start` till `end`
     */
    function _mintableInTimeframe(uint256 start, uint256 end) internal view returns (uint256) {
        require(start <= end, "start > end");

        uint256 currentEpochTime = _startEpochTime;
        uint256 currentRate = _rate;

        // It shouldn't be possible to over/underflow in here but we add checked maths to be safe

        // Special case if end is in future (not yet minted) epoch
        if (end > currentEpochTime + RATE_REDUCTION_TIME) {
            currentEpochTime += RATE_REDUCTION_TIME;
            currentRate = currentRate * RATE_DENOMINATOR / RATE_REDUCTION_COEFFICIENT;
        }

        require(end <= currentEpochTime + RATE_REDUCTION_TIME, "too far in future");

        uint256 toMint = 0;
        for (uint256 epoch = 0; epoch < 999; ++epoch) {
            if (end >= currentEpochTime) {
                uint256 currentEnd = end;
                if (currentEnd > currentEpochTime + RATE_REDUCTION_TIME) {
                    currentEnd = currentEpochTime + RATE_REDUCTION_TIME;
                }

                uint256 currentStart = start;
                if (currentStart >= currentEpochTime + RATE_REDUCTION_TIME) {
                    // We should never get here but what if...
                    break;
                } else if (currentStart < currentEpochTime) {
                    currentStart = currentEpochTime;
                }

                toMint += currentRate * (currentEnd - currentStart);

                if (start >= currentEpochTime) {
                    break;
                }
            }

            currentEpochTime -= RATE_REDUCTION_TIME;
            // double-division with rounding made rate a bit less => good
            currentRate = currentRate * RATE_REDUCTION_COEFFICIENT / RATE_DENOMINATOR;
            assert(currentRate <= INITIAL_RATE);
        }

        return toMint;
    }

    // The below functions are duplicates of functions available above.
    // They are included for ABI compatibility with snake_casing as used in vyper contracts.
    // solhint-disable func-name-mixedcase

    function rate() external view override returns (uint256) {
        return _rate;
    }

    function available_supply() external view returns (uint256) {
        return _availableSupply();
    }

    /**
     * @notice Get timestamp of the current mining epoch start while simultaneously updating mining parameters
     * @return Timestamp of the current epoch
     */
    function start_epoch_time_write() external returns (uint256) {
        return _startEpochTimeWrite();
    }

    /**
     * @notice Get timestamp of the next mining epoch start while simultaneously updating mining parameters
     * @return Timestamp of the next epoch
     */
    function future_epoch_time_write() external returns (uint256) {
        return _startEpochTimeWrite() + RATE_REDUCTION_TIME;
    }

    /**
     * @notice Update mining rate and supply at the start of the epoch
     * @dev Callable by any address, but only once per epoch
     * Total supply becomes slightly larger if this function is called late
     */
    function update_mining_parameters() external {
        require(block.timestamp >= _startEpochTime + RATE_REDUCTION_TIME, "Epoch has not finished yet");
        _updateMiningParameters();
    }

    /**
     * @notice How much supply is mintable from start timestamp till end timestamp
     * @param start Start of the time interval (timestamp)
     * @param end End of the time interval (timestamp)
     * @return Tokens mintable from `start` till `end`
     */
    function mintable_in_timeframe(uint256 start, uint256 end) external view returns (uint256) {
        return _mintableInTimeframe(start, end);
    }
}
