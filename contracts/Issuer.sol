pragma solidity =0.5.12;

import "./interfaces/ICollateralPool.sol";
import "./interfaces/ICurrencyResolver.sol";
import "./interfaces/IExchangeRates.sol";
import "./interfaces/IIssuableSynth.sol";
import "./interfaces/ITRC20Burnable.sol";
import "./libraries/SafeMath.sol";
import "./ownership/Ownable.sol";

contract Issuer is Ownable {
    using SafeMath for uint256;

    ICurrencyResolver public currencyResolver;
    ICollateralPool public collateralPool;
    IExchangeRates public exchangeRates;

    mapping(address => uint256) synthUsdDebts;

    uint256 public issuanceRatio;

    uint256 public constant ISSURANCE_RATIO_ONE = 10**8; // 1.00000000 == 100.000000%

    bytes32 public constant CURRENCY_KEY_SUSD = "sUSD";

    constructor(
        ICurrencyResolver _currencyResolver,
        ICollateralPool _collateralPool,
        IExchangeRates _exchangeRates
    ) public {
        require(
            address(_currencyResolver) != address(0) &&
                address(_collateralPool) != address(0) &&
                address(_exchangeRates) != address(0),
            "Issuer: zero address"
        );

        currencyResolver = _currencyResolver;
        collateralPool = _collateralPool;
        exchangeRates = _exchangeRates;
    }

    function setIssuanceRatio(uint256 ratio) external onlyOwner {
        require(ratio > 0, "Issuer: zero ratio");
        require(ratio != issuanceRatio, "Issuer: same ratio");

        issuanceRatio = ratio;
    }

    function issueSynthUsd(uint256 amount) external {
        require(amount > 0, "Issuer: zero amount");

        // Calculate user's collateral value

        address collateralTokenAddress = collateralPool.collateralToken();
        bytes32 collateralCurrencyKey = currencyResolver.currencyKeysByAddress(
            collateralTokenAddress
        );
        (uint256 collateralRate, ) = exchangeRates.getRateAndTime(
            collateralCurrencyKey
        );

        uint256 collateralBalance = collateralPool.collateralBalances(
            msg.sender
        );

        // WARNING: assumes 18 decimal places of collateral token
        uint256 collateralValue = collateralBalance.mul(collateralRate).div(
            10**18
        );

        require(issuanceRatio > 0, "Issuer: zero ratio");

        // Check if collateral is enough to support the issurance

        uint256 existingDebt = synthUsdDebts[msg.sender];
        uint256 debtAfterIssurance = existingDebt.add(amount);

        uint256 requiredCollateralValue = debtAfterIssurance
            .mul(issuanceRatio)
            .div(ISSURANCE_RATIO_ONE);

        require(
            collateralValue >= requiredCollateralValue,
            "Issuer: insufficient collateral"
        );

        // Create the new synth USD
        synthUsdDebts[msg.sender] = debtAfterIssurance;
        IIssuableSynth(
            currencyResolver.currencyAddressesByKey(CURRENCY_KEY_SUSD)
        )
            .issue(msg.sender, amount);
    }

    function burnSynthUsd(uint256 amount) external {
        require(amount > 0, "Issuer: zero amount");

        uint256 existingDebt = synthUsdDebts[msg.sender];
        uint256 debtAfterBurning = existingDebt.sub(amount);

        synthUsdDebts[msg.sender] = debtAfterBurning;
        ITRC20Burnable(
            currencyResolver.currencyAddressesByKey(CURRENCY_KEY_SUSD)
        )
            .burnFrom(msg.sender, amount);
    }
}
