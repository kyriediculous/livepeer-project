pragma solidity >=0.4.21 <0.6.0;
pragma experimental ABIEncoderV2;

import './interfaces/IERC20.sol';
import './interfaces/IBondingManager.sol';
import './interfaces/IServiceRegistry.sol';

import './libs/ECTools.sol';

contract Wallet {

    address payable master; 

    // EOA => (Contract => (Function signature => bool))
    mapping(address => mapping(address => mapping(bytes4 => bool))) public actors;
    

    modifier onlyMaster() {
        require(msg.sender == master, "Unauthorized");
        _;
    }

    modifier onlyMasterOrActor(address[] memory target, uint256[] memory value, bytes[] memory data, bytes[] memory dataHashSignature) {
		require(target.length <= 8, 'Too much batched transactions');

		for(uint i=0; i< target.length; i++) {
			bytes32 dataHash = keccak256(abi.encodePacked(target[i], value[i], data[i]));
			address signer = getSigner(dataHash, dataHashSignature[i]);
            bytes memory idata = data[i];
            bytes4 sig;
            assembly {
                sig := mload(add(idata, 0x20))
            }
			require(signer == master || actors[signer][target[i]][sig], 'Invalid signature');
		}
		_;
	}

    constructor(address payable _master) public {
        master = _master;
    }

    function () external payable {}

    function approveActorMethod(address _actor, address _contract, bytes4 _sig) external onlyMaster {
        actors[_actor][_contract][_sig]= true;
    }

    function removeActorMethod(address _actor, address _contract, bytes4 _sig) external onlyMaster {
        delete actors[_actor][_contract][_sig];
    }

    function getSigner(bytes32 raw, bytes memory sig) public pure returns(address signer) {
		return ECTools.prefixedRecover(raw, sig);
	}

    // Anyone can execute this but only transactions signed by master or actor (if valid method) are accepted 
	function execute(address[] memory target, uint256[] memory value, bytes[] memory data, bytes[] memory dataHashSignature) public onlyMasterOrActor(target, value, data, dataHashSignature) returns (bool) {
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