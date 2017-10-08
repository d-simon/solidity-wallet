pragma solidity ^0.4.4;

import './Whitelistable.sol';
import './WalletLib.sol';

contract Wallet is Whitelistable {

  // maps the methods of WalletLib onto WalletLib.Request[] (only the array type)
  using WalletLib for WalletLib.Request[];

  WalletLib.Request[] public transfer_requests;

  mapping (address => uint) public spending_limits;

  address public owner;

  // Fired whenever ether is received.
  event Deposit(address indexed depositor, uint value);
  // Fired after every spend()
  event Spent(address indexed sender, address indexed destination, uint value);
  // Fired when a when a new request has been added. The only way to get the id.
  event RequestAdded(uint id, address indexed sender);
  // Fired every time when the request state changes (not necessary for “change” to PENDING)
  event RequestUpdate(uint indexed id, uint state);
  // Fired when the spending limit is updated
  event SpendingLimitUpdated(address indexed addr, uint value);

  modifier onlyOwner {
    require(msg.sender == owner);
    _;
  }

  function Wallet() {
    owner = msg.sender;
  }

  // Fallback Function
  // This needs to have the keyword payable so we can send money to the wallet
  function() payable {
    require(msg.value > 0);
    if (msg.sender != owner) {
      spending_limits[msg.sender] += msg.value;
      SpendingLimitUpdated(msg.sender,spending_limits[msg.sender]);
    }
    Deposit(msg.sender, msg.value);
  }

  // enable the owner (and only the owner) of the contract to set
  // the spending limit for any address
  function setSpendingLimit(address party, uint limit)
  onlyOwner {
    spending_limits[party] = limit;
    SpendingLimitUpdated(party, limit);
  }

  // Implement the spend function. It sends value wei to destination.
  // Value has to be within the spending limit, which is decreased afterwards.
  // For the owner the spending limit is ignored. Also make sure you
  // can deposit into the Wallet.
  function spend(address destination, uint value) {
    if (msg.sender != owner) {
      require(spending_limits[msg.sender] >= value);
      spending_limits[msg.sender] -= value;
      SpendingLimitUpdated(msg.sender, spending_limits[msg.sender]);
    }

    // tranfer automatically reverts in case of failure
    // it is equivalent to `require(address.send(value))``
    destination.transfer(value);
    Spent(msg.sender, destination, value);
  }

  // This creates a new request. Fires the RequestAdded event. Id should
  // increase by one. Initial state is PENDING.
  function request(address destination, uint value, uint timestamp, address token)
  onlyWhitelisted {
    transfer_requests.request(destination, value, timestamp, token);
    // Could also be written as WalletLib.request(transfer_requests, destination, value, timestamp, token);
  }

  // Can only be called by the owner. Checks destination and value. (Because the chain organisation)
  // State changes to APPROVED.
  function approve(uint id, address destination, uint value, uint timestamp, address token)
  onlyOwner {
    transfer_requests.approve(id, destination, value, timestamp, token);
  }

  // Can only be called by the owner. Checks destination and value.
  // State changes to REJECTED.
  function reject(uint id, address destination, uint value, uint timestamp, address token)
  onlyOwner {
    transfer_requests.reject(id, destination, value, timestamp, token);
  }

  // Can only be called by the sender. State needs to be APPROVED and becomes EXECUTED.
  // Ether are sent out to the destination.
  function execute(uint id) {
    transfer_requests.execute(id);
  }

}
