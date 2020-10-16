pragma solidity =0.5.12;

import "./ownership/Ownable.sol";

contract ExchangeRates is Ownable {
    event OracleUpdated(address indexed from, address indexed to);
    event RatesUpdated(
        bytes32[] currencyKeys,
        uint256[] newRates,
        uint256 filter
    );

    struct RateAtTime {
        uint216 rate;
        uint40 time;
    }

    address public oracle;
    mapping(bytes32 => RateAtTime) public rates;

    uint256 private constant MAX_UPDATE_CURRENCY_COUNT = 256;
    uint256 private constant RATE_UPDATE_TX_EXPIRATION = 10 minutes;
    uint256 private constant RATE_UPDATE_TX_FUTURE_LIMIT = 2 minutes;

    modifier onlyOracle() {
        require(msg.sender == oracle, "ExchangeRates: not oracle");
        _;
    }

    function getRateAndTime(bytes32 currencyKey)
        public
        view
        returns (uint256 rate, uint256 time)
    {
        RateAtTime memory rateAndTime = rates[currencyKey];
        return (rateAndTime.rate, rateAndTime.time);
    }

    constructor(address _oracle) public {
        require(_oracle != address(0), "ExchangeRates: zero address");

        oracle = _oracle;
        emit OracleUpdated(address(0), oracle);
    }

    function setOracle(address _oracle) external onlyOwner {
        require(oracle != _oracle, "ExchangeRates: oracle not changed");

        oracle = _oracle;
        emit OracleUpdated(address(0), oracle);
    }

    function updateRates(
        bytes32[] calldata currencyKeys,
        uint256[] calldata newRates,
        uint256 timeSent
    ) external onlyOracle {
        require(
            currencyKeys.length == newRates.length,
            "ExchangeRates: length mismatch"
        );
        require(
            currencyKeys.length > MAX_UPDATE_CURRENCY_COUNT,
            "ExchangeRates: length too large"
        );
        require(
            block.timestamp < timeSent + RATE_UPDATE_TX_EXPIRATION,
            "ExchangeRates: tx expired"
        );
        require(
            timeSent < block.timestamp + RATE_UPDATE_TX_FUTURE_LIMIT,
            "ExchangeRates: tx too far into future"
        );

        // Since the contract ignores stale rates, external observers need a way
        // to tell which updates are successful. The `filter` serves this purpose.
        uint256 filter = 0;

        for (uint256 ind = 0; ind < currencyKeys.length; ind++) {
            bytes32 currentCurrency = currencyKeys[ind];
            RateAtTime memory existingRecord = rates[currentCurrency];

            // Ignore if the incoming rate is even older
            if (timeSent < existingRecord.time) {
                continue;
            }

            filter = filter | (1 << ind);
            rates[currentCurrency] = RateAtTime({
                rate: uint216(newRates[ind]),
                time: uint40(timeSent)
            });
        }

        // A zero `filter` means no update is valid
        require(filter > 0, "ExchangeRates: no update");

        emit RatesUpdated(currencyKeys, newRates, filter);
    }
}
