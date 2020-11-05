pragma solidity ^0.5.0;

interface IExchangeRates {
    function getRateAndTime(bytes32 currencyKey)
        external
        view
        returns (uint256 rate, uint256 time);
}
