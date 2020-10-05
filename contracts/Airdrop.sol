pragma solidity =0.5.12;

import "./interfaces/IAirdropHub.sol";
import "./interfaces/ITRC20.sol";
import "./interfaces/ITRC20Burnable.sol";
import "./libraries/SafeMath.sol";

contract Airdrop {
    using SafeMath for uint256;

    event Staked(address indexed staker, uint256 indexed amount);
    event Unstaked(address indexed staker, uint256 indexed amount);
    event AirdropReward(address indexed staker, uint256 indexed amount);
    event ReferralReward(
        address indexed referrer,
        address indexed referred,
        uint256 indexed amount
    );

    address public hub;
    address public stakeToken;
    address public airdropToken;
    uint256 public airdropAmount;
    uint256 public snapshotTime;
    uint256 public referralRate;

    bool public initialized;
    bool public remainingBurnt;
    uint256 public currentStakerCount;
    uint256 public totalStakedAmount;
    mapping(address => uint256) public stakedAmounts;

    bool public snapshotTaken;
    uint256 public snapshotedStakedAmount;
    uint256 public snapshotedStakeTokenSupply;

    uint256 public accuAirdropReward;
    uint256 public accuReferralReward;

    uint256 public constant PERCENTAGE_100 = 10000;
    uint256 public constant MAX_REFERRAL_RATE = 10000; // Hard-coded upper limit for referral rate: 100%

    modifier onlyHub() {
        require(msg.sender == hub, "Airdrop: not hub");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == IAirdropHub(hub).owner(), "Airdrop: not owner");
        _;
    }

    modifier onlyInitialized() {
        require(initialized, "Airdrop: not initialized");
        _;
    }

    modifier onlyEnded() {
        require(block.timestamp >= snapshotTime, "Airdrop: not ended");
        _;
    }

    modifier onlyNotEnded() {
        require(block.timestamp < snapshotTime, "Airdrop: ended");
        _;
    }

    modifier onlyNoStaker() {
        require(currentStakerCount == 0, "Airdrop: not zero staker");
        _;
    }

    constructor(
        uint256 _airdropAmount,
        uint256 _snapshotTime,
        uint256 _referralRate
    ) public {
        require(_airdropAmount > 0, "Airdrop: zero amount");
        require(
            _snapshotTime > block.timestamp,
            "Airdrop: snapshot time in the past"
        );
        require(
            _referralRate <= MAX_REFERRAL_RATE,
            "Airdrop: referral rate out of range"
        );

        hub = msg.sender;
        stakeToken = IAirdropHub(msg.sender).stakeToken();
        airdropToken = IAirdropHub(msg.sender).airdropToken();
        airdropAmount = _airdropAmount;
        snapshotTime = _snapshotTime;
        referralRate = _referralRate;
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
     * @dev This funtion is called by hub to verify that the amount of airdropToken
     * is already available in the contract.
     */
    function initialize() external onlyHub {
        require(!initialized, "Airdrop: not initialized");
        require(
            ITRC20(airdropToken).balanceOf(address(this)) == airdropAmount,
            "Airdrop: airdrop amount mismatch"
        );

        initialized = true;
    }

    /**
     * @dev Stake the entire remaining token balance. Cannot be called after snapshot time.
     */
    function stake(address referrer) external onlyInitialized onlyNotEnded {
        _stake(msg.sender, ITRC20(stakeToken).balanceOf(msg.sender), referrer);
    }

    /**
     * @dev Stake the specified amount of tokens. Cannot be called after snapshot time.
     */
    function stake(uint256 amount, address referrer)
        external
        onlyInitialized
        onlyNotEnded
    {
        _stake(msg.sender, amount, referrer);
    }

    /**
     * @dev Unstake all staked tokens.
     *
     * Users can unstake at any time, including before the snapshot time.
     */
    function unstake() external onlyInitialized {
        _unstake(msg.sender, stakedAmounts[msg.sender], true);
    }

    /**
     * @dev Unstake a specified amount of tokens. This function can only be called
     * before snapshot. After snapshot users can only unstake all tokens. There's no
     * reason to partially unstake after snapshot anyways.
     */
    function unstake(uint256 amount) external onlyInitialized onlyNotEnded {
        _unstake(msg.sender, amount, true);
    }

    /**
     * @dev Unstake all staked tokens, but without getting airdrop rewards.
     *
     * This is en emergency exit for getting the staked tokens backed just in case there's
     * something wrong with the reward calculation. There shouldn't be any but we're putting
     * it here just to be safe.
     *
     * This can only be voluntarily done by the staker. The contract owner cannot force a staker
     * to unstake without reward (there's no `unstakeForWithoutReward`).
     */
    function unstakeWithoutReward() external onlyInitialized {
        _unstake(msg.sender, stakedAmounts[msg.sender], false);
    }

    /**
     * @dev Return the staked tokens to stakers along with airdrop rewards if they
     * forget to do so.
     *
     * In principle we shouldn't even care whether users unstake or not. However,
     * since some functions require all stakers to have exited to work, this function
     * is put in place.
     */
    function unstakeFor(address staker)
        external
        onlyOwner
        onlyInitialized
        onlyEnded
    {
        _unstake(staker, stakedAmounts[staker], true);
    }

    /**
     * @dev Unstake all staked tokens. See `unstake()` on AirdropHub for details.
     */
    function unstakeFromHub(address staker) external onlyInitialized onlyHub {
        _unstake(staker, stakedAmounts[staker], true);
    }

    /**
     * @dev This function is for withdrawing TRX from the contract in case someone
     * accidentally sends TRX to the address. In Ethereum we can mostly avoid this
     * making the contract non-payable, but that doesn't work in Tron as a normal
     * transfer won't trigger any contract code (not even the fallback function).
     *
     * When this happens the team will withdraw TRX and return to the original sender.
     *
     * This method does NOT need to be marked `onlyNoStaker` because stakers would
     * never deposit TRX. There's no risk to stakers' funds.
     */
    function withdrawTrx(uint256 amount) external onlyOwner onlyInitialized {
        msg.sender.transfer(amount);
    }

    /**
     * @dev This function is for withdrawing any TRC20 tokens from the contract in case
     * someone sends tokens directly to the contract without using the stake() function.
     *
     * When this happens the team will withdraw the tokens and return to the original sender.
     *
     * Note that since this function is marked with `onlyNoStaker`, it's only callable when
     * all stakers have withdrawan their staked tokens. Stakers' funds are safe. It's NOT
     * possible for the contract owner to withdraw staked tokens.
     */
    function withdrawTrc20(address token, uint256 amount)
        external
        onlyOwner
        onlyInitialized
        onlyNoStaker
    {
        ITRC20(token).transfer(msg.sender, amount);
    }

    /**
     * @dev This function is used for burning airdrop tokens left. For this to work, stakeToken
     * must implement ITRC20Burnable.
     */
    function burn() external onlyOwner onlyInitialized onlyEnded onlyNoStaker {
        require(!remainingBurnt, "Airdrop: already burnt");

        remainingBurnt = true;
        ITRC20Burnable(stakeToken).burn(
            airdropAmount.sub(accuAirdropReward).sub(accuReferralReward)
        );
    }

    function _stake(
        address staker,
        uint256 amount,
        address referrer
    ) private {
        require(amount > 0, "Airdrop: zero amount");

        uint256 stakedAmountBefore = stakedAmounts[staker];

        // Update state
        stakedAmounts[staker] = stakedAmountBefore.add(amount);
        totalStakedAmount = totalStakedAmount.add(amount);
        if (stakedAmountBefore == 0) {
            currentStakerCount = currentStakerCount.add(1);
        }

        // Transfer stakeToken and build referral
        IAirdropHub(hub).transferFrom(staker, amount);
        IAirdropHub(hub).registerReferral(referrer, staker);

        emit Staked(staker, amount);
    }

    function _unstake(
        address staker,
        uint256 amount,
        bool withReward
    ) private {
        require(amount > 0, "Airdrop: zero amount");

        // No need to check balance sufficiency as `sub` will throw anyways
        uint256 userStakedAmountBefore = stakedAmounts[staker];
        uint256 userStakedAmountAfter = userStakedAmountBefore.sub(amount);
        uint256 totalStakedAmountBefore = totalStakedAmount;

        // Update state
        stakedAmounts[staker] = userStakedAmountAfter;
        totalStakedAmount = totalStakedAmountBefore.sub(amount);
        if (userStakedAmountAfter == 0) {
            currentStakerCount = currentStakerCount.sub(1);
        }

        // Return the staked token to user first
        require(
            ITRC20(stakeToken).transfer(staker, amount),
            "Airdrop: TRC20 trnasfer failed"
        );

        emit Unstaked(staker, amount);

        // Settle the airdrop reward
        if (withReward && block.timestamp >= snapshotTime) {
            // It should only be possible to unstake all after snapshot time
            assert(userStakedAmountAfter == 0);

            // Take snapshot first if not already taken
            if (!snapshotTaken) {
                snapshotTaken = true;
                snapshotedStakedAmount = totalStakedAmountBefore;
                snapshotedStakeTokenSupply = ITRC20(stakeToken).totalSupply();
            }

            uint256 airdropReward = userStakedAmountBefore
                .mul(airdropAmount)
                .mul(snapshotedStakedAmount)
                .div(snapshotedStakeTokenSupply);

            // It's possible that reward is zero if the staked amount is too small
            if (airdropReward > 0) {
                accuAirdropReward = accuAirdropReward.add(airdropReward);
                require(
                    ITRC20(airdropToken).transfer(staker, airdropReward),
                    "Airdrop: TRC20 trnasfer failed"
                );

                emit AirdropReward(staker, airdropReward);

                // Settle referral reward
                address referrer = IAirdropHub(hub).referrersByReferred(staker);
                if (referrer != address(0)) {
                    uint256 referralReward = airdropReward
                        .mul(referralRate)
                        .div(PERCENTAGE_100);

                    if (referralReward > 0) {
                        accuReferralReward = accuReferralReward.add(
                            referralReward
                        );
                        require(
                            ITRC20(airdropToken).transfer(
                                referrer,
                                referralReward
                            ),
                            "Airdrop: TRC20 trnasfer failed"
                        );

                        emit ReferralReward(referrer, staker, referralReward);

                        IAirdropHub(hub).addReferralReward(
                            referrer,
                            referralReward
                        );
                    }
                }
            }
        }
    }
}
