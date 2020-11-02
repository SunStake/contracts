pragma solidity =0.5.12;

import "./ownership/Ownable.sol";

/**
 * @dev This contract stores currency keys and addresses mappings.
 */
contract CurrencyResolver is Ownable {
    mapping(address => bytes32) currencyKeysByAddress;
    mapping(bytes32 => address) currencyAddressesByKey;

    function addCurrency(bytes32 key, address tokenAddress) public onlyOwner {
        require(key > 0, "CurrencyResolver: empty key");
        require(tokenAddress != address(0), "CurrencyResolver: zero address");
        require(
            currencyKeysByAddress[tokenAddress] == 0 &&
                currencyAddressesByKey[key] == address(0),
            "CurrencyResolver: currency exists"
        );

        currencyKeysByAddress[tokenAddress] = key;
        currencyAddressesByKey[key] = tokenAddress;
    }
}
