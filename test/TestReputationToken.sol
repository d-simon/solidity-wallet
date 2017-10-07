pragma solidity >= 0.4.15;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/ReputationToken.sol";
import "../contracts/Wallet.sol";
import "./ThrowProxy.sol";

contract TestReputationToken {

  uint public initialBalance = 10 ether;

  function testInflate() {
    var token = new ReputationToken();
    address destination = msg.sender;
    Assert.equal(token.balanceOf(destination), 0,
      "expected initial balance to be 0");
    token.inflate(destination, 10);
    Assert.equal(token.balanceOf(destination), 10,
      "expected balance to be 10");
    token.inflate(destination, 100);
    Assert.equal(token.balanceOf(destination), 110,
      "expected initial balance to be 110");
  }

  function testInflateNotOwner() {
    var proxy = new ThrowProxy(DeployedAddresses.ReputationToken());
    ReputationToken(proxy).inflate(msg.sender, 100);
    Assert.isFalse(proxy.execute.gas(200000)(), 'should throw');
  }

  // the owner can spend ether from the wallet (no need to the other accounts)
  function testOwnerCanSpendEther() {
    var wallet = new Wallet();
    address destination = 0xF50783a4E8792cB6078E56b086f2d90C3bbA18cb;
    var initialDestinationBalance = destination.balance;

    wallet.transfer(10000);
    wallet.spend(destination, 10000);

    Assert.equal(destination.balance, initialDestinationBalance + 10000, "expected destination balance to be 10000");
  }

  // the owner can whitelist someone
  function testOwnerCanWhitelist() {
    var wallet = new Wallet();
    address destination = 0x8298E0F47252c6e63953A67d95351b942325be23;

    wallet.setWhitelisted(destination, true);

    Assert.equal(wallet.whitelisted(destination), true, "expected destination to be whitelisted");
  }

  // other accounts cannot whitelist someone
  function testOthersCannotWhitelist() {
    var proxy = new ThrowProxy(new Wallet());

    address destination = 0xC380b17e9e9fd0BbA53adA7B391cb6dda55b687c;

    Wallet(proxy).setWhitelisted(destination, true);
    Assert.isFalse(proxy.execute.gas(200000)(), 'should throw');
  }

}
