pragma solidity ^0.5.0;

interface ITRC20Burnable {
    function burn(uint256 amount) external;

    function burnFrom(address account, uint256 amount) external;
}
