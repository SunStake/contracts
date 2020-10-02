pragma solidity =0.5.12;

import "./tokens/TRC20.sol";
import "./tokens/TRC20Detailed.sol";

/**
 * @dev This token is for mocking TRC20 tokens in tests.
 */
contract AnyToken is TRC20, TRC20Detailed {
    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals,
        uint256 totalSupply
    ) public TRC20Detailed(name, symbol, decimals) {
        _mint(msg.sender, totalSupply);
    }
}
