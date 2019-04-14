pragma solidity >=0.4.21 <0.6.0;

import './interfaces/IServiceRegistry.sol';


/// @title ServiceRegistry
/// @author Nico Vergauwen <vergauwennico@gmail.com>
/// @notice Set/Lookup a URI endpoint for off-chain communication 
contract ServiceRegistry is IServiceRegistry {

    /// @notice maps endpoint to ethereum address of a worker
    mapping(address => string) public serviceURIs; 

    /// @notice Set URI 
    /// @param _serviceURI (string) URI
    function setServiceURI(string calldata _serviceURI) external {
        serviceURIs[msg.sender] = _serviceURI;
    }
}
