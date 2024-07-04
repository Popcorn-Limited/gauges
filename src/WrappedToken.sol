pragma solidity >=0.8.0;

import {IERC20, IERC20Metadata} from "openzeppelin-contracts/contracts/interfaces/IERC20Metadata.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

contract WrappedToken is ERC20 {
    IERC20 public underlying;

    constructor(
        address underlying_
    )
        ERC20(
            string.concat("Wrapped ", IERC20Metadata(underlying_).name()),
            string.concat("w", IERC20Metadata(underlying_).symbol()),
            IERC20Metadata(underlying_).decimals()
        )
    {
        underlying = IERC20(underlying_);
    }

    function wrap(uint256 amount) external {
        return wrap(msg.sender, amount);
    }

    function wrap(address to, uint256 amount) public {
        underlying.transferFrom(msg.sender, address(this), amount);

        _mint(to, amount);
    }

    function unwrap(uint256 amount) external {
        return unwrap(msg.sender, amount);
    }

    function unwrap(address to, uint256 amount) public {
        _burn(msg.sender, amount);

        underlying.transfer(to, amount);
    }
}
