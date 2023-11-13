pragma solidity >=0.8.0;

import {IERC20} from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {Owned} from "solmate/auth/Owned.sol";

contract VCX is ERC20, Owned {
    IERC20 internal constant POP =
        IERC20(0xD0Cd466b34A24fcB2f87676278AF2005Ca8A78c4);
    uint public endOfMigrationTs;
    uint256 maxSupply = 1e26; // @dev cant mint more than 100m VCX

    event Migrated(address indexed user, uint popAmount, uint vcxAmount);
    event UpdatedEndOfMigrationTs(uint oldTs, uint newTs);

    constructor(
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol, 18) Owned(msg.sender) {
        endOfMigrationTs = block.timestamp + 365 days;
    }

    // @param amount the amount of POP you want to migrate
    function migrate(address to, uint amount) external {
        if (block.timestamp > endOfMigrationTs) revert("CLOSED");
        uint256 toMint = amount * 10;
        if (totalSupply + toMint > maxSupply) revert("MAX_SUPPLY");

        POP.transferFrom(msg.sender, address(this), amount);
        _mint(to, toMint);

        emit Migrated(msg.sender, amount, amount * 10);
    }

    function setEndOfMigrationTs(uint ts) external onlyOwner {
        uint old = endOfMigrationTs;
        endOfMigrationTs = ts;

        emit UpdatedEndOfMigrationTs(old, ts);
    }
}
