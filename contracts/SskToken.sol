pragma solidity =0.5.12;

import "./ownership/Ownable.sol";
import "./tokens/TRC20Burnable.sol";
import "./tokens/TRC20Detailed.sol";

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

    function isMinter(address account) public view returns (bool) {
        require(account != address(0), "SSK: account is the zero address");
        return _minters[account];
    }

    function addMinter(address account) public onlyOwner {
        require(!isMinter(account), "SSK: already a minter");
        _minters[account] = true;
    }

    function removeMinter(address account) public onlyOwner {
        require(isMinter(account), "SSK: not a minter");
        _minters[account] = false;
    }

    function mint(address account, uint256 amount)
        public
        onlyMinter
        returns (bool)
    {
        _mint(account, amount);
        return true;
    }
}
