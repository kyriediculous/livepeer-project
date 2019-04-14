pragma solidity >=0.4.21 <0.6.0;
pragma experimental ABIEncoderV2;

import './interfaces/IERC20.sol';
import './interfaces/IBondingManager.sol';
import './interfaces/IServiceRegistry.sol';

import './libs/ECTools.sol';

/// @title  Wallet
/// @author Nico Vergauwen <vergauwennico@gmail.com>
/// @notice Wallet contract that can execute meta transactions on behalf of authorized signers
contract Wallet {

    /// @notice master owner 
    address payable master; 

    /// @notice EOA => (Contract => (Function signature => bool))
    mapping(address => mapping(address => mapping(bytes4 => bool))) public actors;
    

    /// @dev Access modifier that requires 'msg.sender' to be 'master'
    modifier onlyMaster() {
        require(msg.sender == master, "Unauthorized");
        _;
    }

    /// @dev Access modifier that checks whether meta transactions are signed by authorized EOA's
    modifier onlyMasterOrActor(address[] memory target, uint256[] memory value, bytes[] memory data, bytes[] memory dataHashSignature) {
		for(uint i=0; i< target.length; i++) {
            require(isValidSignature(target[i], value[i], data[i], dataHashSignature[i]));
		}
		_;
	}

    /// @notice Sets the master address upon deployment
    /// @param _master (address) Ethereum address for the master 
    constructor(address payable _master) public {
        master = _master;
    }

    /// @notice Fallback 
    function() external payable {}

    /// @notice Allows master to approve external contract transactions for an actor 
    /// @param _actor (address) the actor's ethereum address 
    /// @param _contract (address) the target contract 
    /// @param _sig (bytes4) the function signature (8 bytes prefixed with 0x) 
    function approveActorMethod(address _actor, address _contract, bytes4 _sig) external onlyMaster {
        actors[_actor][_contract][_sig]= true;
    }

    /// @notice Allows master to revoke an actors access to certain external contract transactions 
    /// @param _actor (address) the actor's ethereum address 
    /// @param _contract (address) the target contract 
    /// @param _sig (bytes4) the function signature (8 bytes prefixed with 0x)
    function removeActorMethod(address _actor, address _contract, bytes4 _sig) external onlyMaster {
        delete actors[_actor][_contract][_sig];
    }

    /// @notice Get the signer of a transaction through ecrecover
    /// @param raw (bytes32) keccak256 hash of the ABI encoded transaction data 
    /// @param sig (bytes) the signature resulting from signing 'raw'
    /// @return signer (address) the EOA that signed the data 
    function getSigner(bytes32 raw, bytes memory sig) public pure returns(address signer) {
		return ECTools.prefixedRecover(raw, sig);
	}

    /// @notice Checks whether the signer is an authorized EOA
    /// @param target (address) contract target address 
    /// @param value (uint256) Wei amount being send in the transaction 
    /// @param data (bytes) data being send in the transaction 
    /// @param sig (bytes) the signature of the transaction data 
    /// @return isValid (bool) true/false based on whether the signer is master or an actor that has access rights to the method at 'target'
    function isValidSignature(address target, uint256 value, bytes memory data, bytes memory sig) public view returns (bool isValid) {
        bytes32 dataHash = keccak256(abi.encodePacked(target, value, data));
        address signer = getSigner(dataHash, sig);
        bytes4 method;
        assembly {
            method := mload(add(data, 0x20))
        }
        return (signer == master || actors[signer][target][method]);
    }

    /// @notice Execute a batch of meta transactions atomically
    /// @dev Anyone can execute this but only transactions signed by master or actor (if valid method) are accepted 
    /// @param target (address[]) Array of contract addresses
    /// @param value (uint256[]) Array of wei amounts being sent in the respective transactions 
    /// @param data (bytes[]) Array of ABI encoded transaction data 
    /// @param dataHashSignature (bytes[]) Array of transaction signatures for the respective transaction data
    /// @return (bool) returns true if all transactions in the batch succeeded
	function execute(address[] memory target, uint256[] memory value, bytes[] memory data, bytes[] memory dataHashSignature) public onlyMasterOrActor(target, value, data, dataHashSignature) returns (bool) {
		require(target.length <= 8, 'Too many batched transactions');
        for(uint i=0; i< target.length; i++) {
			(bool success,) = target[i].call.value(value[i])(data[i]);
			require(success, 'Excuting MetaTx Failed');
		}
		return true;
    }

    /*
    function sendETH(address payable _to, uint _amount)
        public
        onlyMaster
        {
            require(_to != address(0), "Invalid recipient");
            _to.transfer(_amount);
    }

    function sendERC20(address _to, address _token, uint _amount)
        public
        onlyMaster
        {
        require(_to != address(0), "Invalid recipient");
        IERC20(_token).transfer(_to, _amount);
    }

    function withdrawETH(uint _amount) external onlyMaster {
        sendETH(master, _amount);
    }

    function withdrawERC20(address _token, uint _amount) external onlyMaster {
        sendERC20(master, _token, _amount);
    }
    */
}
