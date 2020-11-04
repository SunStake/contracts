pragma solidity ^0.5.0;

interface IIssuableSynth {
    function issue(address recipient, uint256 amount) external;
}
