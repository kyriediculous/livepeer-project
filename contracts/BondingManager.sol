pragma solidity >=0.4.21 <0.6.0;

import './interfaces/IBondingManager.sol';
import './interfaces/IERC20.sol';

import './libs/SafeMath.sol';

/// @title BondingManager
/// @author Nico Vergauwen <vergauwennico@gmail.com>
/// @notice staking contract that is used to stake tokens and register as a worker 

contract BondingManager is IBondingManager {
    using SafeMath for uint256;

    /// @notice The ERC20 token being used, mapped to it's interface
    IERC20 public token;

    /// @notice Registered workers 
    mapping(address => bool) public workers;

    /// @notice A user's bonds towards different delegates 
    mapping(address => mapping(address => uint256)) public bonds;

    /// @notice total stake associated with an address (bonded to self + from delegated to)
    mapping(address => uint256) public stakes;
    
    /// @notice Sets an ERC20 token to be used with the BondingManager upon deployment
    /// @param _token (address) address of an ERC20 token
    constructor(IERC20 _token) public {
        token = _token;
    }
    
    /// @notice locks up tokens in the BondingManager and adjust state accordingly
    /// @param _delegate (address) ethereum address to delegate to, can be self 
    /// @param _amount (uint256) the amount to bond (and delegate)
    function bond(address _delegate, uint256 _amount) external {
        bonds[msg.sender][_delegate] = bonds[msg.sender][_delegate].add(_amount);
        stakes[_delegate] = stakes[_delegate].add(_amount);
        token.transferFrom(msg.sender, address(this), _amount);
        // emit event 
    }

    /// @notice withdraws tokens back from the BondingManager and adjusts state accordingly
    /// @param _delegate (address) ethereum address of the delegate to unstake tokens from, can be self 
    /// @param _amount (uint256) the amount of tokens to unbond 
    function unbond(address _delegate, uint256 _amount) external {
        bonds[msg.sender][_delegate] = bonds[msg.sender][_delegate].sub(_amount);
        stakes[_delegate] = stakes[_delegate].sub(_amount);
        token.transfer(msg.sender, _amount);
        // emit event       
    }

    /// @notice register 'msg.sender' as a worker 
    /// @dev requires 'msg.sender' to have stake 
    function register() external {
        require(stakes[msg.sender] > 0, "Not enough stake");
        workers[msg.sender] = true;
    }

    /// @notice removes 'msg.sender' from the active worker list
    function unregister() external {
        delete workers[msg.sender];
    }
}
