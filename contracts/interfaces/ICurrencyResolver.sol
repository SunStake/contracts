pragma solidity ^0.5.0;

interface ICurrencyResolver {
    function currencyKeysByAddress(address tokenAddress)
        external
        view
        returns (bytes32);

    function currencyAddressesByKey(bytes32 key)
        external
        view
        returns (address);

    function addCurrency(bytes32 key, address tokenAddress) external;
}
