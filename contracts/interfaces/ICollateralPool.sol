pragma solidity ^0.5.0;

interface ICollateralPool {
    function collateralToken() external view returns (address);

    function collateralBalances(address staker) external view returns (uint256);
}
