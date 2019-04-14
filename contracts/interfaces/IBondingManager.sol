pragma solidity >=0.4.21 <0.6.0;

// Interface for a staking contract that is used to stake
// tokens and register as a worker
interface IBondingManager {
    // Stakes `_amount` tokens from the sender by locking
    // them in the contract and delegates the tokens to
    // `_delegate`
    function bond(address _delegate, uint256 _amount) external;
    // Registers the sender as a worker
    function register() external;
}
