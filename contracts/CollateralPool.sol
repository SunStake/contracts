pragma solidity =0.5.12;

import "./interfaces/ICurrencyResolver.sol";
import "./interfaces/IExchangeRates.sol";
import "./interfaces/IIssuer.sol";
import "./interfaces/ITRC20.sol";
import "./libraries/SafeMath.sol";
import "./ownership/Ownable.sol";

/**
 * @dev This contract holds collateral assets pooled by stakers and keeps track of each
 * staker's share. Only TRC20 collateral is supported at the moment.
 */
contract CollateralPool is Ownable {
    using SafeMath for uint256;

    address public collateralToken;

    ICurrencyResolver public currencyResolver;
    IExchangeRates public exchangeRates;
    IIssuer public issuer;

    mapping(address => uint256) collateralBalances;

    uint256 public constant ISSURANCE_RATIO_ONE = 10**8; // 1.00000000 == 100.000000%

    constructor(
        address _collateralToken,
        ICurrencyResolver _currencyResolver,
        IExchangeRates _exchangeRates
    ) public {
        require(
            _collateralToken != address(0) &&
                address(_currencyResolver) != address(0) &&
                address(_exchangeRates) != address(0),
            "CollateralPool: zero address"
        );

        collateralToken = _collateralToken;
        currencyResolver = _currencyResolver;
        exchangeRates = _exchangeRates;
    }

    // NOTE: We can't put issuer on ctor as issuer also depends on this contract.
    // TODO: Change to service locator pattern before going live to fix this.
    function setIssuer(address _issuer) external onlyOwner {
        require(_issuer != address(0), "CollateralPool: zero address");
        issuer = IIssuer(_issuer);
    }

    function postCollateral(uint256 amount) external {
        _postCollateral(msg.sender, amount);
    }

    function withdrawCollateral() external {
        _withdrawCollateral(msg.sender, collateralBalances[msg.sender]);
    }

    function withdrawCollateral(uint256 amount) external {
        _withdrawCollateral(msg.sender, amount);
    }

    function _postCollateral(address staker, uint256 amount) private {
        require(amount > 0, "CollateralPool: zero amount");

        collateralBalances[staker] = collateralBalances[staker].add(amount);
        ITRC20(collateralToken).transferFrom(staker, address(this), amount);
    }

    function _withdrawCollateral(address staker, uint256 amount) private {
        require(amount > 0, "CollateralPool: zero amount");

        // Check if remaining balance is enough to support debt (if any)
        uint256 balanceAfterWithdrawal = collateralBalances[staker].sub(amount);
        uint256 issuanceRatio = issuer.issuanceRatio();

        bytes32 collateralCurrencyKey = currencyResolver.currencyKeysByAddress(
            collateralToken
        );
        (uint256 collateralRate, ) = exchangeRates.getRateAndTime(
            collateralCurrencyKey
        );

        // WARNING: assumes 18 decimal places of collateral token
        uint256 collateralValueAfter = balanceAfterWithdrawal
            .mul(collateralRate)
            .div(10**18);

        uint256 requiredCollateralValue = issuer
            .synthUsdDebts(staker)
            .mul(issuanceRatio)
            .div(ISSURANCE_RATIO_ONE);

        require(
            collateralValueAfter >= requiredCollateralValue,
            "CollateralPool: insufficient collateral after withdrawal"
        );

        collateralBalances[staker] = balanceAfterWithdrawal;
        ITRC20(collateralToken).transfer(staker, amount);
    }
}
