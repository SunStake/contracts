pragma solidity =0.5.12;

import "./interfaces/IAirdropV1.sol";
import "./interfaces/IAirdropHubV1.sol";
import "./interfaces/ITRC20.sol";

/**
 * @dev This contract is a read-only helper contract for optimizing front-end
 * queries. Instead of issuing multiple `triggerConstantContract` requests, this
 * contract allows fetching data in a single request.
 */
contract Query {
    address airdropHub;

    constructor(address _airdropHub) public {
        airdropHub = _airdropHub;
    }

    function getAirdropData(address airdrop, address user)
        public
        view
        returns (uint256[] memory)
    {
        /**
         * 00 -> Stake token total supply
         * 01 -> User stake token balance
         * 02 -> User airdrop token balance
         * 03 -> User hub allowance
         * 04 -> Current staker count
         * 05 -> Current staked amount
         * 06 -> User staked amount
         * 07 -> Snapshot taken
         * 08 -> Snapshot staker count
         * 09 -> Snapshot staked amount
         * 10 -> Snapshot stake token supply
         */
        uint256[] memory result = new uint256[](11);

        address stakeToken = IAirdropV1(airdrop).stakeToken();
        address airdropToken = IAirdropV1(airdrop).airdropToken();

        result[0] = ITRC20(stakeToken).totalSupply();
        result[1] = ITRC20(stakeToken).balanceOf(user);
        result[2] = ITRC20(airdropToken).balanceOf(user);
        result[3] = ITRC20(stakeToken).allowance(user, airdropHub);
        result[4] = IAirdropV1(airdrop).currentStakerCount();
        result[5] = IAirdropV1(airdrop).totalStakedAmount();
        result[6] = IAirdropV1(airdrop).stakedAmounts(user);
        result[7] = IAirdropV1(airdrop).snapshotTaken() ? 1 : 0;
        result[8] = IAirdropV1(airdrop).snapshotedStakerCount();
        result[9] = IAirdropV1(airdrop).snapshotedStakedAmount();
        result[10] = IAirdropV1(airdrop).snapshotedStakeTokenSupply();

        return result;
    }

    function getReferralData(address user)
        public
        view
        returns (uint256[] memory)
    {
        /**
         * 00 -> Total referral count
         * 01 -> Total referral reward
         * 02 -> User referral count
         * 03 -> User referral reward
         */
        uint256[] memory result = new uint256[](4);

        result[0] = IAirdropHubV1(airdropHub).totalReferralCount();
        result[1] = IAirdropHubV1(airdropHub).totalReferralReward();
        result[2] = IAirdropHubV1(airdropHub).referralCountsByReferrer(user);
        result[3] = IAirdropHubV1(airdropHub).referralRewardsByReferrer(user);

        return result;
    }
}
