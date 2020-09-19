pragma solidity =0.5.12;

import "./ownership/Ownable.sol";
import "./tokens/TRC20Burnable.sol";
import "./tokens/TRC20Detailed.sol";

/**
 * @dev The token contract is marked Ownable to allow an account to manage
 * minters. The SunStake team will transfer ownership to an upgradable DAO
 * governance contract once the platform is considered mature. The team will
 * only use the minting functionality to distribute initial tokens.
 *
 * This contract also features the capability of locking up minting. which
 * rejects all minting requests until a specified timestamp that can be further
 * extended if necessary. The team will lock up the minting functionality once
 * it finishs the initial token distribution so that users won't have to trust
 * the team to not mint additional tokens.
 *
 * Idealy only peer-reviewed smart contracts should be added as minters.
 * Adding an external owned accounts (EOA) as minter is dangerous.
 */
contract SskToken is
    TRC20Burnable,
    TRC20Detailed("SunStake", "SSK", 18),
    Ownable
{
    uint256 public mintingUnlockTime;

    mapping(address => bool) _minters;

    modifier onlyMinter() {
        require(isMinter(msg.sender), "SSK: caller is not a minter");
        _;
    }

    modifier mintingNotLocked() {
        require(!isMintingLocked(), "SSK: minting is locked");
        _;
    }

    /**
     * @dev Returns if the address specified is a minter
     * @return bool
     */
    function isMinter(address account) public view returns (bool) {
        require(account != address(0), "SSK: account is the zero address");
        return _minters[account];
    }

    /**
     * @dev Returns if minting is locked up now
     * @return bool
     */
    function isMintingLocked() public view returns (bool) {
        return mintingUnlockTime > 0 && block.timestamp < mintingUnlockTime;
    }

    /**
     * @dev Adds an account as minter.
     */
    function addMinter(address account) public onlyOwner {
        require(!isMinter(account), "SSK: already a minter");
        _minters[account] = true;
    }

    /**
     * @dev Removes account as minter.
     */
    function removeMinter(address account) public onlyOwner {
        require(isMinter(account), "SSK: not a minter");
        _minters[account] = false;
    }

    /**
     * @dev Extends the minting lock-up period.
     */
    function setMintingUnlockTime(uint256 unlockTime) public onlyOwner {
        require(
            unlockTime > mintingUnlockTime,
            "SSK: only extension is allowed"
        );
        mintingUnlockTime = unlockTime;
    }

    /**
     * @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     * @return bool
     */
    function mint(address account, uint256 amount)
        public
        onlyMinter
        mintingNotLocked
        returns (bool)
    {
        _mint(account, amount);
        return true;
    }

    /**
     * @dev Changes token contract name. This function is added to combat Tronscan
     * token name censorship.
     */
    function setName(string memory newName) public onlyOwner {
        _setName(newName);
    }
}
