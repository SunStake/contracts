pragma solidity ^0.5.0;

interface IAirdropHub {
    function owner() external view returns (address);

    function stakeToken() external view returns (address);

    function airdropToken() external view returns (address);

    function referrersByReferred(address referred)
        external
        view
        returns (address);

    function registerReferral(address referrer, address referred)
        external
        returns (bool);

    function addReferralReward(address referrer, uint256 amount) external;

    function transferFrom(address from, uint256 amount) external;
}
