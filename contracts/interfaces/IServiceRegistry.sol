pragma solidity >=0.4.21 <0.6.0;

// Interface for a service registry contract that is used
// to look up the URI to be used for off-chain communication
// for an ETH address
interface IServiceRegistry {
    // Sets the URI of the sender which can be used to
    // connect with the sender off-chain
    function setServiceURI(string calldata _uri) external;
}