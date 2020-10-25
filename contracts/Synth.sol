pragma solidity =0.5.12;

import "./ownership/Ownable.sol";
import "./tokens/TRC20Detailed.sol";

/**
 * @dev This contract represents a synthetic asset and implements the TRC20
 * standard, with a hard-coded fixed precision of 18 decimals.
 */
contract Synth is Ownable, TRC20Detailed {
    constructor(string memory name, string memory symbol)
        public
        TRC20Detailed(name, symbol, 18)
    {}
}
