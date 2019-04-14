pragma solidity >=0.4.21 <0.6.0;

import './interfaces/IBondingManager.sol';
import './interfaces/IERC20.sol';

import './libs/SafeMath.sol';

contract BondingManager is IBondingManager {
    using SafeMath for uint256;

    IERC20 public token;

    mapping(address => bool) public workers;
    mapping(address => mapping(address => uint256)) public bonds;
    mapping(address => uint256) public stakes;
    
    constructor(IERC20 _token) public {
        token = _token;
    }
    
    // bond 
    function bond(address _delegate, uint256 _amount) external {
        bonds[msg.sender][_delegate] = bonds[msg.sender][_delegate].add(_amount);
        stakes[_delegate] = stakes[_delegate].add(_amount);
        token.transferFrom(msg.sender, address(this), _amount);
        // emit event 
    }

    // unbond 
    function unbond(address _delegate, uint256 _amount) external {
        bonds[msg.sender][_delegate] = bonds[msg.sender][_delegate].sub(_amount);
        stakes[_delegate] = stakes[_delegate].sub(_amount);
        token.transfer(msg.sender, _amount);
        // emit event       
    }

    // register 
    function register() external {
        require(stakes[msg.sender] > 0, "Not enough stake");
        workers[msg.sender] = true;
    }

    // unregister 
    function unregister() external {
        delete workers[msg.sender];
    }
}