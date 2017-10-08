require('chai')
    .use(require('chai-as-promised'))
    .use(require('chai-bignumber')(web3.BigNumber))
    .should();

const promisify = (inner) => new Promise((resolve, reject) => inner((err, res) => err ? reject(err) : resolve(res)));
const getBalance = (addr) => promisify((cb) => web3.eth.getBalance(addr, cb))
const getTransaction = (txHash) => promisify((cb) => web3.eth.getTransaction(txHash, cb))
const increaseTime = (time) => promisify((cb) => web3.currentProvider.sendAsync({ jsonrpc: '2.0', method: 'evm_increaseTime', params: [time], id: 0 }, cb))

const big = (n) => web3.toBigNumber(n);
const ether = (n) => web3.toWei(n);

const computeCost = async (receipt) => {
  let { gasPrice } = await getTransaction(receipt.transactionHash);
  return gasPrice.times(receipt.gasUsed);
}

const Wallet = artifacts.require("./Wallet.sol");
const ReputationToken = artifacts.require("./ReputationToken.sol");
const WalletProxy = artifacts.require("./WalletProxy.sol");

contract('Wallet', function(accounts) {
  const [owner, creator, guest1, guest2, maliciousGuest, randomAddress] = accounts;

  const initialDepositAmount = big(ether(10));
  const spendAmount = big(123124);
  const requestAmount = big(23456789);

  const PENDING = big(0);
  const APPROVED = big(1);
  const EXECUTED = big(2);
  const REJECTED = big(3);

  it('should receive deposit by owner', async function () {
    // We need to instantiate the WalletProxy (with its actual address) as a Wallet Object
    // so we have access to all the functions. => The WalletProxy is then interpreted as a
    // Wallet (while actually all calls get delegated to the actual Wallet)
    let w = await Wallet.at((await WalletProxy.deployed()).address);
    let { logs } = await w.sendTransaction({ value: initialDepositAmount, from: owner });
    verifyLogs(logs, [
      { event: 'Deposit', args: { depositor: owner, value: initialDepositAmount }}
    ])
    ;(await getBalance(w.address)).should.deep.equal(initialDepositAmount)
  })


  it('should allow owner to spend (without spending limit)', async function () {
    let w = await Wallet.at((await WalletProxy.deployed()).address);
    let { logs } = await w.spend(randomAddress, spendAmount, { from: owner });
    verifyLogs(logs, [
      { event: 'Spent', args: {
        sender: owner,
        destination: randomAddress,
        value: spendAmount
      }}
    ])
  })


  it('should receive deposit by guest and update spending limit', async function () {
    let w = await Wallet.at((await WalletProxy.deployed()).address);
    let { logs } = await w.sendTransaction({ value: initialDepositAmount, from: guest1 });
    verifyLogs(logs, [
      { event: 'SpendingLimitUpdated', args: { addr: guest1, value: initialDepositAmount }},
      { event: 'Deposit', args: { depositor: guest1, value: initialDepositAmount }}
    ])
  })


  it('should allow the owner to whitelist addresses (guest)', async function () {
    let w = await Wallet.at((await WalletProxy.deployed()).address);
    let { logs } = await w.setWhitelisted(guest1, true, { from: owner });
    verifyLogs(logs, [
      { event: 'Whitelisted', args: {
        addr: guest1,
        value: true
      }}
    ])
  })


  it('should deny a randomAddress to whitelist addresses', async function () {
    let w = await Wallet.at((await WalletProxy.deployed()).address);
    await w.setWhitelisted(randomAddress, true, {
      from: randomAddress
    }).should.be.rejectedWith('invalid opcode')
  })


  it('should not take requests from non-whitelisted randomAddress', async function () {
    let w = await Wallet.at((await WalletProxy.deployed()).address);
    let timeDifference = 500;
    let futureTimeStamp = big(Math.floor(Date.now() / 1000 + timeDifference));
    // request with self-benificiary
    await w.request(randomAddress, requestAmount, futureTimeStamp, 0, {
      from: randomAddress
    }).should.be.rejectedWith('invalid opcode')
  })


  it('should take requests from whitelisted guest', async function () {
    let w = await Wallet.at((await WalletProxy.deployed()).address);
    let timeDifference = 500;
    let futureTimeStamp = big(Math.floor(Date.now() / 1000 + timeDifference));
    let { logs } = await w.request(guest2, requestAmount, futureTimeStamp, 0, { from: guest1 });
    verifyLogs(logs, [
      { event: 'RequestAdded', args: {
        sender: guest1,
        id: big(0)
      }}
    ])
  })


  it('should execute requests', async function () {
    let w = await Wallet.at((await WalletProxy.deployed()).address);
    let timeDifference = 500;
    let futureTimeStamp = big(Math.floor(Date.now() / 1000 + timeDifference));
    let id = big(1);

    let { logs } = await w.request(guest2, requestAmount, futureTimeStamp, 0, { from: guest1 });
    verifyLogs(logs, [
      { event: 'RequestAdded', args: {
        sender: guest1,
        id
      }}
    ])

    let approveRes = await w.approve(id, guest2, requestAmount, futureTimeStamp, 0, { from: owner });
    verifyLogs(approveRes.logs, [
      { event: 'RequestUpdate', args: {
        id,
        state: APPROVED
      }}
    ])

    let executeRes = await w.execute(id, { from: guest1 });
    verifyLogs(executeRes.logs, [
      { event: 'RequestUpdate', args: {
        id,
        state: EXECUTED
      }}
    ])
  })


  it('should execute token requests (ReputationToken)', async function () {
    let w = await Wallet.at((await WalletProxy.deployed()).address);
    let rep = await ReputationToken.at(ReputationToken.address);

    let timeDifference = 500;
    let futureTimeStamp = big(Math.floor(Date.now() / 1000 + timeDifference));
    let id = big(2);

    let tokenRequestAmount = big(1000);
    let topUp = big(10000);

    // Add a balance of FREP tokens to the wallet contract
    await rep.inflate(w.address, topUp, { from: owner })

    let { logs } = await w.request(guest2, tokenRequestAmount, futureTimeStamp, rep.address, { from: guest1 });
    verifyLogs(logs, [
      { event: 'RequestAdded', args: {
        sender: guest1,
        id
      }}
    ])

    let approveRes = await w.approve(id, guest2, tokenRequestAmount, futureTimeStamp, rep.address, { from: owner });
    verifyLogs(approveRes.logs, [
      { event: 'RequestUpdate', args: {
        id,
        state: APPROVED
      }}
    ])

    let initialBalanceGuest2 = await rep.balanceOf(guest2);

    let executeRes = await w.execute(id, { from: guest1 });
    verifyLogs(executeRes.logs, [
      { event: 'RequestUpdate', args: {
        id,
        state: EXECUTED
      }}
    ])

    ;(await rep.balanceOf(guest2)).should.deep.equal(initialBalanceGuest2.plus(tokenRequestAmount))
  })


  it('should not execute requests after timeout', async function () {
    let w = await Wallet.at((await WalletProxy.deployed()).address);
    let timeDifference = 500;
    let futureTimeStamp = big(Math.floor(Date.now() / 1000 + timeDifference));
    let id = big(3);

    let { logs } = await w.request(guest2, requestAmount, futureTimeStamp, 0, { from: guest1 });
    verifyLogs(logs, [
      { event: 'RequestAdded', args: {
        sender: guest1,
        id
      }}
    ])

    let approveRes = await w.approve(id, guest2, requestAmount, futureTimeStamp, 0, { from: owner });
    verifyLogs(approveRes.logs, [
      { event: 'RequestUpdate', args: {
        id,
        state: APPROVED
      }}
    ])

    await increaseTime(timeDifference * 2)

    await w.execute(id, { from: guest1 }).should.be.rejectedWith('invalid opcode')
  })


  it('should not execute rejected requests', async function () {
    let w = await Wallet.at((await WalletProxy.deployed()).address);
    let timeDifference = 500;
    let futureTimeStamp = big(Math.floor(Date.now() / 1000 + timeDifference));
    let id = big(4);

    let { logs } = await w.request(guest2, requestAmount, futureTimeStamp, 0, { from: guest1 });
    verifyLogs(logs, [
      { event: 'RequestAdded', args: {
        sender: guest1,
        id
      }}
    ])

    let rejectRes = await w.reject(id, guest2, requestAmount, futureTimeStamp, 0, { from: owner });
    verifyLogs(rejectRes.logs, [
      { event: 'RequestUpdate', args: {
        id,
        state: REJECTED
      }}
    ])

    await w.execute(id, { from: guest1 }).should.be.rejectedWith('invalid opcode')

    // Also check after the timeout has run out (just in case)
    await increaseTime(timeDifference * 2)
    await w.execute(id, { from: guest1 }).should.be.rejectedWith('invalid opcode')
  })

  // it('should write test', async function () {
  //   assert.fail('','','No test!')
  // })
})

function verifyLogs(logs, expectedLogs) {
  return expectedLogs.forEach((expected, index) => {
    let l = logs[index];
    assert.isObject(l, `Expected is an object (${expected.event})`);
    l.event.should.equal(expected.event)
    l.args.should.deep.equal(expected.args)
  });
}
