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
 * Idealy only peer-reviewed smart contracts should be added as minters.
 * Adding an external owned accounts (EOA) as minter is dangerous.
 */
contract SskToken is
    TRC20Burnable,
    TRC20Detailed("SunStake", "SSK", 18),
    Ownable
{
    mapping(address => bool) _minters;

    modifier onlyMinter() {
        require(isMinter(msg.sender), "SSK: caller is not a minter");
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
     * @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     * @return bool
     */
    function mint(address account, uint256 amount)
        public
        onlyMinter
        returns (bool)
    {
        _mint(account, amount);
        return true;
    }
}
