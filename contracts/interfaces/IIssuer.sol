pragma solidity ^0.5.0;

interface IIssuer {
    function synthUsdDebts(address user) external view returns (uint256);

    function issuanceRatio() external view returns (uint256);
}
