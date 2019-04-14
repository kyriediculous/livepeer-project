pragma solidity >=0.4.21 <0.6.0;

import './interfaces/IServiceRegistry.sol';


contract ServiceRegistry is IServiceRegistry {

    mapping(address => string) public serviceURIs; 

    function setServiceURI(string calldata _serviceURI) external {
        serviceURIs[msg.sender] = _serviceURI;
    }
}