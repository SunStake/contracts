pragma solidity ^0.5.0;

interface IAirdropV1 {
    function stakeToken() external view returns (address);

    function airdropToken() external view returns (address);

    function currentStakerCount() external view returns (uint256);

    function totalStakedAmount() external view returns (uint256);

    function stakedAmounts(address staker) external view returns (uint256);

    function unstakeFromHub(address staker) external;
}
