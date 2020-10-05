pragma solidity =0.5.12;

import "./Airdrop.sol";
import "./interfaces/IAirdrop.sol";
import "./interfaces/ITRC20.sol";
import "./ownership/Ownable.sol";

/**
 * @dev This contract serves as a central repository for maintaining the list
 * of airdrops and referral relationships. It also acts as a token spending proxy
 * such that users only need to make approval once, and are then able to participate
 * in multiple airdrops.
 */
contract AirdropHub is Ownable {
    event NewAirdrop(address indexed airdropAddress);
    event Referral(address indexed referrer, address indexed referred);

    address public stakeToken;
    address public airdropToken;
    uint256 public airdropCount;
    address[] public airdrops;
    mapping(address => bool) public airdropMap;
    mapping(address => address) public referrersByReferred;

    // On-chain statistics (can be replaced by off-chain data processing)
    uint256 public totalReferralCount;
    uint256 public totalReferralReward;
    mapping(address => uint256) public referralCountsByReferrer;
    mapping(address => uint256) public referralRewardsByReferrer;

    /**
     * @dev Functions annotated by this modifier can only be called by airdrop
     * contracts created from this hub. These callers are considered trusted.
     */
    modifier onlyAirdrop() {
        require(airdropMap[msg.sender], "AirdropHub: not airdrop");
        _;
    }

    constructor(address _stakeToken, address _airdropToken) public {
        require(
            _stakeToken != address(0) && _airdropToken != address(0),
            "Airdrop: zero address"
        );

        stakeToken = _stakeToken;
        airdropToken = _airdropToken;
    }

    /**
     * @dev We're marking the fallback function as payable so that we can test it with
     * tools from Ethereum. Doing this does NOT make it easier to send funds by mistake.
     *
     * On Tron, simple TRX transfers do not trigger contract code, as opposed to Ethereum
     * where the fallback function is invoked. So making the fallback function non-payable
     * won't stop users from accidentally sending TRX. It's necessary to mark the fallback
     * payable to mock this behavior on Ethereum.
     */
    function() external payable {}

    /**
     * @dev Create a new airdrop contract. `amount` of airdropToken will be transferred
     * from owner to the newly-created airdrop contract.
     */
    function createAirdrop(
        uint256 airdropAmount,
        uint256 snapshotTime,
        uint256 referralRate
    ) external onlyOwner returns (address) {
        require(airdropAmount > 0, "AirdropHub: zero amount");
        require(snapshotTime > block.timestamp, "AirdropHub: time in the past");

        Airdrop newAirdrop = new Airdrop(
            airdropAmount,
            snapshotTime,
            referralRate
        );

        ITRC20(airdropToken).transferFrom(
            msg.sender,
            address(newAirdrop),
            airdropAmount
        );

        newAirdrop.initialize();

        airdropCount = airdropCount + 1; // No need for safe math
        airdrops.push(address(newAirdrop));
        airdropMap[address(newAirdrop)] = true;

        emit NewAirdrop(address(newAirdrop));

        return address(newAirdrop);
    }

    /**
     * @dev Unstake all tokens from a specific airdrop. This has the exact same effect
     * as calling `unstake()` on the airdrop contract directly.
     *
     * This function is actually pointless, as calling it is literally the same as invoking
     * `unstake()` on the airdrop contract. The only reason it's put here is due to a bug
     * currently on Tronscan, which causes the contract react/write functionalities for
     * contract-generated contraces to not display properly.
     *
     * Of course, calling contract functions can be dong without using a user interface.
     * However, many non-technical users rely on the availability of this Tronscan UI. It is
     * thus put here to provide an emergency exit for non-technical users should the SunStake
     * UI becomes unavailable for any reason.
     */
    function unstake(address airdrop) external {
        require(airdropMap[airdrop], "AirdropHub: not airdrop");
        IAirdrop(airdrop).unstakeFromHub(msg.sender);
    }

    /**
     * @dev Register referral relationship. This function is only callable from airdrop
     * contracts generated through this hub (`onlyAirdrop`).
     * @return bool Whether the referral relationship is successfully established.
     */
    function registerReferral(address referrer, address referred)
        external
        onlyAirdrop
        returns (bool)
    {
        // Cannot refer self
        if (referrer == referred) return false;

        // Cannot overwrite existing referrals
        if (referrersByReferred[referred] != address(0)) return false;

        referrersByReferred[referred] = referrer;

        // No need for safe math. It's just stats. Better off saving tx cost
        totalReferralCount = totalReferralCount + 1;
        referralCountsByReferrer[referrer] =
            referralCountsByReferrer[referrer] +
            1;

        emit Referral(referrer, referred);

        return true;
    }

    /**
     * @dev This function is only use for statistics. No safe math needed
     */
    function addReferralReward(address referrer, uint256 amount)
        external
        onlyAirdrop
    {
        totalReferralReward = totalReferralReward + amount;
        referralRewardsByReferrer[referrer] =
            referralRewardsByReferrer[referrer] +
            amount;
    }

    /**
     * @dev Transfer stakeToken from users to an airdrop contract. This function is only
     * callable from airdrop contracts generated through this hub (`onlyAirdrop`). The hub
     * acts as an approval proxy here.
     */
    function transferFrom(address from, uint256 amount) external onlyAirdrop {
        require(amount > 0, "AirdropHub: zero amount");
        require(
            ITRC20(stakeToken).transferFrom(from, msg.sender, amount),
            "AirdropHub: TRC20 trnasfer failed"
        );
    }

    /**
     * @dev This function is for withdrawing TRX from the contract in case someone
     * accidentally sends TRX to the address.
     *
     * When this happens the team will withdraw TRX and return to the original sender.
     */
    function withdrawTrx(uint256 amount) external onlyOwner {
        msg.sender.transfer(amount);
    }

    /**
     * @dev This function is for withdrawing any TRC20 tokens from the contract in case
     * someone accidentally sends tokens to this contract.
     *
     * When this happens the team will withdraw the tokens and return to the original sender.
     *
     * Note that this hub contract is NOT directly involved in the staking process. Staked tokens
     * are NOT stored here. Therefore it's perfectly safe to have this emergency withdrawal
     * function in place. No user funds are at risk because of this.
     */
    function withdrawTrc20(address token, uint256 amount) external onlyOwner {
        ITRC20(token).transfer(msg.sender, amount);
    }
}
