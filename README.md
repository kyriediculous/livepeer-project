# Livepeer Take Home Project 

## Assignment 

Bonding mechanism where transactions are executed atomically. 
[https://hackmd.io/Qhq6C5JNSiKLUxr_VBMbLg?view](https://hackmd.io/Qhq6C5JNSiKLUxr_VBMbLg?view)

## Part 1 

`npm install`

`truffle test`

All transactions are executed through the `execute()` method. This method takes in a batch of transaction data (through arrays) and executes them in turn. 

For example `ERC20.approve()` can be batched together with another function that invokes `ERC20.transferFrom()` and then performs some sort of action. When transferFrom fails due to inadequate balance or other reasons, the approval will be reverted as well. Before the approval would have to be manually reset back to avoid possible malicious actions on already approved tokens that the user forgot to revoke back. 

Anyone can call the `execute()` function but it will only pass if all meta-transactions in the batch to be executed are signed by the master, or an actor for which the method is approved. 

Signatures are verified using `ecrecover` which returns the signer of the address. 

The master can approve different actors to use external contract methods in the same way by calling `approveActorMethod() `with the actor's address, target and function signature. Analogous the master can revoke an actor's access by calling `removeActorMethod()` with the same paremeters. 


## Part 2 

Assuming a worker will call something like `verifyAndReward(bytes memory data, bytes memory sig)`

The verification contract would have to check whether the worker is an EOA or contract address (using `extcodesize`). 

If the worker is a contract address, the verification contract needs to call a verification method on the wallet contract representing the worker. 

In our `Wallet.sol` this method is called `isValidSignature()` but for real world applications such method would likely need to be standardized through an interface if the Wallet contract is to be used cross-dapp. 


```
    function isValidSignature(
        address target,
        uint256 value,
        bytes memory data,
        bytes memory sig
        ) public view returns (bool isValid) 
        {
            bytes32 dataHash = keccak256(abi.encodePacked(target, value, data));
            address signer = getSigner(dataHash, sig);
            bytes4 method;
            assembly {
                method := mload(add(data, 0x20))
            }
            return (signer == master || actors[signer][target][method]);
    }
```

Alternatively if it is for arbitrary bytes that are signed and not transactions we can take the `hash of the signed data` and the `resulting signature` as inputs, use `ecrecover` and check whether the signer is authorized to sign arbitrary bytes. (see `getSigner()` in `Wallet.sol`)