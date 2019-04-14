const Wallet = artifacts.require('Wallet')
const BondingManager = artifacts.require('BondingManager')
const ServiceRegistry = artifacts.require('ServiceRegistry')
const ECTools = artifacts.require('ECTools')
const Token = artifacts.require('Token')
const utils = require('ethers').utils

const assertRevert = async promise => {
    try {
      await promise
      assert.fail('Expected error not received')
    } catch (error) {
      const rev = error.message.search('revert') >= 0
      assert(rev, `Expected "revert", got ${error.message} instead`)
    }
  }

contract('Wallet.sol ETH hold/send/receive', (accounts) => {
    let wallet, ecTools;
    before(async () => {
        ecTools = await ECTools.new()
        await Wallet.link('ECTools', ecTools.address)
        wallet = await Wallet.new(accounts[0]) 
    })

    it('Wallet can receive $ETH', async () => {
        await wallet.sendTransaction({value: "100"})
        assert.equal("100", (await web3.eth.getBalance(wallet.address)).toString(10))
    })

    it('$ETH can be withdrawn from wallet', async () => {
        // encode & sign a transaction with no data and master as target 
        const transferHash = utils.solidityKeccak256(['address', 'uint256', 'bytes'], [accounts[0], 100, '0x0'])
        const transferSignature = await web3.eth.sign(transferHash, accounts[0])
        // Execute the meta transaction , this will make the contract send ether 
        await wallet.execute([accounts[0]], [100], ['0x0'], [transferSignature])
        // await wallet.withdrawETH('100')
        assert.equal("0", (await web3.eth.getBalance(wallet.address)).toString(10))
    })

    it('Only master can withdraw $ETH', async () => {
        // Do the same but this time sign with an account that does not have permissions
        await wallet.sendTransaction({value: "100"})
        const transferHash = utils.solidityKeccak256(['address', 'uint256', 'bytes'], [accounts[1], 100, '0x0'])
        const transferSignature = await web3.eth.sign(transferHash, accounts[1])
        await assertRevert(wallet.execute([accounts[1]], [100], ['0x0'], [transferSignature], {from: accounts[1]}))
        // await assertRevert(wallet.withdrawETH('100', {from: accounts[1]}))
    })
})

contract('Wallet.sol ERC20 hold/send/receive', (accounts) => {
    let wallet, token, ecTools;
    before(async () => {
        ecTools = await ECTools.new()
        await Wallet.link('ECTools', ecTools.address)
        wallet = await Wallet.new(accounts[0])
        token = await Token.new("TestToken", "TEST", 18)
        // give master some tokens 
        let tx = await token.mint(accounts[0], "1000")
    })

    it('Wallet can receive ERC20', async () => {
        // transfer tokens to wallet contract
        await token.transfer(wallet.address, "1000")
        assert.equal((await token.balanceOf(wallet.address)).toString(10), "1000")
    })

    it('ERC20 can be withdrawn from wallet', async () => {
        // Encode & sign a transaction that calls ERC20.transfer()
        const transferData = token.contract.methods.transfer(accounts[0], "1000").encodeABI()
        const transferHash = utils.solidityKeccak256(['address', 'uint256', 'bytes'], [token.address, 0, utils.arrayify(transferData)])
        const transferSignature = await web3.eth.sign(transferHash, accounts[0])
        // Execute the meta transaction on behalf of the wallet contract, making it send ERC20 tokens to master
        await wallet.execute([token.address], [0], [transferData], [transferSignature])
        // await wallet.withdrawERC20(token.address, "1000")
        assert.equal((await token.balanceOf(accounts[0])).toString(10), "1000")
        assert.equal((await token.balanceOf(wallet.address)).toString(10), "0")
    })

    it('Only master can withdraw ERC20', async () => {
        // Same thing but sign with an account that does not have permissions
        await token.transfer(wallet.address, "10")
        const transferData = token.contract.methods.transfer(accounts[1], "10").encodeABI()
        const transferHash = utils.solidityKeccak256(['address', 'uint256', 'bytes'], [token.address, 0, utils.arrayify(transferData)])
        const transferSignature = await web3.eth.sign(transferHash, accounts[1])
        await assertRevert(wallet.execute([token.address], [0], [transferData], [transferSignature]))
        // await assertRevert(wallet.withdrawERC20(token.address, "10", {from: accounts[1]}))
    })
})

contract('Wallet.sol atomic operations with meta transactions', (accounts) => {
    let wallet, token, bondingManager, serviceRegistry, ecTools,
        approveData, approveHash, approveSignature,
        bondData, bondHash, bondSignature;
    beforeEach( async () => {
        ecTools = await ECTools.new()
        await Wallet.link('ECTools', ecTools.address)
        wallet = await Wallet.new(accounts[0])
        token = await Token.new("TestToken", "TEST", 18)
        let tx = await token.mint(wallet.address, "1000")
        bondingManager = await BondingManager.new(token.address)
        serviceRegistry = await ServiceRegistry.new()

        // encode and sign an ERC20.approve transaction
        approveData = token.contract.methods.approve(bondingManager.address, "500").encodeABI()
        approveHash = utils.solidityKeccak256(['address', 'uint256', 'bytes'], [token.address, 0, utils.arrayify(approveData)])
        approveSignature = await web3.eth.sign(approveHash, accounts[0])

        // encode and sign a transaction for a contract call that implements ERC20.transferFrom()
        bondData = bondingManager.contract.methods.bond(wallet.address, "500").encodeABI()
        bondHash = utils.solidityKeccak256(['address', 'uint256', 'bytes'], [bondingManager.address, 0, utils.arrayify(bondData)])
        bondSignature = await web3.eth.sign(bondHash, accounts[0])
    })

    it('Executes ERC20.approve and ERC20.transferFrom atomically', async () => {
        // Execute our signed transactions 
        await wallet.execute([token.address, bondingManager.address], [0, 0], [approveData, bondData], [approveSignature, bondSignature])
        assert.equal((await bondingManager.stakes(wallet.address)).toString(10), "500")
        assert.equal((await bondingManager.bonds(wallet.address, wallet.address)).toString(10), "500")
        assert.equal((await token.balanceOf(bondingManager.address)).toString(10), "500")
        assert.equal((await token.balanceOf(wallet.address)).toString(10), "500")
    })

    it('Executes bonding and registering atomically', async () => {
        // encode and sign a transaction that calls a method to register as a worker 
        const registerData = bondingManager.contract.methods.register().encodeABI()
        const registerHash = utils.solidityKeccak256(['address', 'uint256', 'bytes'], [bondingManager.address, 0, utils.arrayify(registerData)])
        const registerSignature = await web3.eth.sign(registerHash, accounts[0])

        // encode and sign a transaction to set a URI on the service registry 
        const setURIdata = serviceRegistry.contract.methods.setServiceURI('hello world').encodeABI()
        const setURIhash = utils.solidityKeccak256(['address', 'uint256', 'bytes'], [serviceRegistry.address, 0, utils.arrayify(setURIdata)])
        const setURIsignature = await web3.eth.sign(setURIhash, accounts[0])

        // Execute the transactions on behalf of the wallet contract making him a worker and setting 'hello world' as URI on the service contract 
        await wallet.execute(
            [token.address, bondingManager.address, bondingManager.address, serviceRegistry.address],
            [0, 0, 0, 0],
            [approveData, bondData, registerData, setURIdata],
            [approveSignature, bondSignature, registerSignature, setURIsignature]
        )
        assert.equal((await bondingManager.bonds(wallet.address, wallet.address)).toString(10), "500")
        assert.equal(true, await bondingManager.workers(wallet.address))
        assert.equal("hello world", await serviceRegistry.serviceURIs(wallet.address))
    })

    it('Reverts all transactions when one fails', async () => {
        const registerData = bondingManager.contract.methods.register().encodeABI()
        const registerHash = utils.solidityKeccak256(['address', 'uint256', 'bytes'], [bondingManager.address, 0, utils.arrayify(registerData)])
        const registerSignature = await web3.eth.sign(registerHash, accounts[0])

        const setURIdata = serviceRegistry.contract.methods.setServiceURI('hello world').encodeABI()
        const setURIhash = utils.solidityKeccak256(['address', 'uint256', 'bytes'], [serviceRegistry.address, 0, utils.arrayify(setURIdata)])
        // Generate a signature from an account that does not have access rights so it will revert and thus revert all tx in the batch
        const setURIsignature = await web3.eth.sign(setURIhash, accounts[1])

        await assertRevert(wallet.execute(
            [token.address, bondingManager.address, bondingManager.address, serviceRegistry.address],
            [0, 0, 0, 0],
            [approveData, bondData, registerData, setURIdata],
            [approveSignature, bondSignature, registerSignature, setURIsignature]
        ))
        assert.equal((await bondingManager.bonds(wallet.address, wallet.address)).toString(10), "0")
        assert.equal(false, await bondingManager.workers(wallet.address))
    })
})

contract('Wallet.sol actor access management', (accounts) => {
    let wallet, token, bondingManager, serviceRegistry, ecTools,
    approveData, approveHash, approveSignature,
    bondData, bondHash, bondSignature;
    before( async () => {
        ecTools = await ECTools.new()
        await Wallet.link('ECTools', ecTools.address)
        wallet = await Wallet.new(accounts[0])
        token = await Token.new("TestToken", "TEST", 18)
        let tx = await token.mint(wallet.address, "1000")
        bondingManager = await BondingManager.new(token.address)
        serviceRegistry = await ServiceRegistry.new()

        approveData = token.contract.methods.approve(bondingManager.address, "500").encodeABI()
        approveHash = utils.solidityKeccak256(['address', 'uint256', 'bytes'], [token.address, 0, utils.arrayify(approveData)])
        approveSignature = await web3.eth.sign(approveHash, accounts[0])

        bondData = bondingManager.contract.methods.bond(wallet.address, "500").encodeABI()
        bondHash = utils.solidityKeccak256(['address', 'uint256', 'bytes'], [bondingManager.address, 0, utils.arrayify(bondData)])
        bondSignature = await web3.eth.sign(bondHash, accounts[0])
    })

    it('Can allow an actor to use an external method, eg ERC20.transfer(address, uint)', async () => {

        // allow actor to use ERC20.transfer() 
        await wallet.approveActorMethod(accounts[1], token.address, '0xa9059cbb')
        assert.equal(await wallet.actors(accounts[1], token.address, '0xa9059cbb'), true)

        // try a transfer
        const transferData = token.contract.methods.transfer(accounts[1], "1000").encodeABI()
        const transferHash = utils.solidityKeccak256(['address', 'uint256', 'bytes'], [token.address, 0, utils.arrayify(transferData)])
        const transferSignature = await web3.eth.sign(transferHash, accounts[1])
        await wallet.execute([token.address], [0], [transferData], [transferSignature])
        assert.equal((await token.balanceOf(accounts[1])).toString(10), "1000")
        assert.equal((await token.balanceOf(wallet.address)).toString(10), "0")

    })

    it('Can revoke access to external methods for an actor', async () => {
        await wallet.removeActorMethod(accounts[1], token.address, '0xa9059cbb')
        assert.equal(await wallet.actors(accounts[1], token.address, '0xa9059cbb'), false)

        const transferData = token.contract.methods.transfer(accounts[1], "1000").encodeABI()
        const transferHash = utils.solidityKeccak256(['address', 'uint256', 'bytes'], [token.address, 0, utils.arrayify(transferData)])
        const transferSignature = await web3.eth.sign(transferHash, accounts[1])
        await assertRevert(wallet.execute([token.address], [0], [transferData], [transferSignature]))
    })
})
