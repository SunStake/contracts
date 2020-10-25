pragma solidity =0.5.12;

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

    mapping(address => uint256) collateralBalances;

    constructor(address _collateralToken) public {
        require(_collateralToken != address(0), "CollateralPool: zero address");

        collateralToken = _collateralToken;
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
        require(false, "NOT_IMPLEMENTED");

        require(amount > 0, "CollateralPool: zero amount");

        collateralBalances[staker] = collateralBalances[staker].add(amount);
        ITRC20(collateralToken).transferFrom(staker, address(this), amount);
    }

    function _withdrawCollateral(address staker, uint256 amount) private {
        require(false, "NOT_IMPLEMENTED");

        require(amount > 0, "CollateralPool: zero amount");

        collateralBalances[staker] = collateralBalances[staker].sub(amount);
        ITRC20(collateralToken).transfer(staker, amount);
    }
}
