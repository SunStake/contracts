pragma solidity ^0.5.0;

// Credit: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v2.5.1/contracts/token/ERC20/ERC20Burnable.sol
// Renamed from ERC20 to TRC20

import "./TRC20.sol";

contract TRC20Burnable is TRC20 {
    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
    }

    function burnFrom(address account, uint256 amount) public {
        _burnFrom(account, amount);
    }
}
