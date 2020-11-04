pragma solidity =0.5.12;

import "./Synth.sol";

/**
 * @dev This contract represents a synthetic asset that can be issued by an
 * external contract.
 */
contract IssuableSynth is Synth {
    address public issuer;

    modifier onlyIssuer() {
        require(msg.sender == issuer, "IssuableSynth: not issuer");
        _;
    }

    constructor(
        address _issuer,
        string memory name,
        string memory symbol
    ) public Synth(name, symbol) {
        require(_issuer != address(0), "IssuableSynth: zero address");

        issuer = _issuer;
    }

    function issue(address recipient, uint256 amount) external onlyIssuer {
        require(recipient != address(0), "IssuableSynth: zero address");
        require(amount > 0, "IssuableSynth: zero amount");

        _mint(recipient, amount);
    }
}
