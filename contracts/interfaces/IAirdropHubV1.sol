pragma solidity ^0.5.0;

interface IAirdropHubV1 {
    function owner() external view returns (address);

    function stakeToken() external view returns (address);

    function airdropToken() external view returns (address);

    function referrersByReferred(address referred)
        external
        view
        returns (address);

    function totalReferralCount() external view returns (uint256);

    function totalReferralReward() external view returns (uint256);

    function referralCountsByReferrer(address referrer)
        external
        view
        returns (uint256);

    function referralRewardsByReferrer(address referrer)
        external
        view
        returns (uint256);

    function registerReferral(address referrer, address referred)
        external
        returns (bool);

    function addReferralReward(address referrer, uint256 amount) external;

    function transferFrom(address from, uint256 amount) external;
}
