pragma solidity ^0.4.4;

import './Whitelisted.sol';
import './zeppelin/token/ERC20.sol';

contract Wallet is Whitelisted {
  mapping (address => uint) public spendingLimits;

  Request[] public transferRequests;
  address public owner;

  enum RequestState {
    PENDING,
    APPROVED,
    EXECUTED,
    REJECTED
  }

  struct Request {
    address sender;
    address destination;
    uint value;
    RequestState state;
    uint timestamp;
    ERC20 token;
  }

  // Fired whenever ether is received.
  event Deposit(address indexed depositor, uint value);
  // Fired after every spend()
  event Spent(address indexed sender, address indexed destination, uint value);
  // Fired when a when a new request has been added. The only way to get the id.
  event RequestAdded(uint id, address indexed sender);
  // Fired every time when the request state changes (not necessary for “change” to PENDING)
  event RequestUpdate(uint indexed id, RequestState state);
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
      spendingLimits[msg.sender] += msg.value;
    }
    Deposit(msg.sender, msg.value);
  }

  // enable the owner (and only the owner) of the contract to set
  // the spending limit for any address
  function setSpendingLimit(address party, uint limit)
  onlyOwner {
    spendingLimits[party] = limit;
    SpendingLimitUpdated(party, limit);
  }

  // Implement the spend function. It sends value wei to destination.
  // Value has to be within the spending limit, which is decreased afterwards.
  // For the owner the spending limit is ignored. Also make sure you
  // can deposit into the Wallet.
  function spend(address destination, uint value) {
    if (msg.sender != owner) {
      require(spendingLimits[msg.sender] >= value);
      spendingLimits[msg.sender] -= value;
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
    transferRequests.push(Request({
      sender: msg.sender,
      destination: destination,
      value: value,
      state: RequestState.PENDING,
      timestamp: timestamp,
      token: ERC20(token)
    }));
    RequestAdded(transferRequests.length - 1, msg.sender);
  }

  modifier checkRequest (uint id, address destination, uint value, uint timestamp, address token, RequestState expected) {
    Request storage req = transferRequests[id];
    require(req.state == expected);
    require(req.destination == destination);
    require(req.value == value);
    require(req.token == token);
    require(req.timestamp == timestamp);
    _;
  }

  // Can only be called by the owner. Checks destination and value. (Because the chain organisation)
  // State changes to APPROVED.
  function approve(uint id, address destination, uint value, uint timestamp, address token)
  onlyOwner checkRequest(id, destination, value, timestamp, token, RequestState.PENDING) {
    Request storage req = transferRequests[id];
    req.state = RequestState.APPROVED;
    RequestUpdate(id, req.state);
  }

  // Can only be called by the owner. Checks destination and value.
  // State changes to REJECTED.
  function reject(uint id, address destination, uint value, uint timestamp, address token)
  onlyOwner checkRequest(id, destination, value, timestamp, token, RequestState.PENDING) {
    Request storage req = transferRequests[id];
    req.state = RequestState.REJECTED;
    RequestUpdate(id, req.state);
  }

  // Can only be called by the sender. State needs to be APPROVED and becomes EXECUTED.
  // Ether are sent out to the destination.
  function execute(uint id) {
    Request storage req = transferRequests[id];
    require(msg.sender == req.sender);
    require(req.state == RequestState.APPROVED);
    require(now < req.timestamp);

    req.state = RequestState.EXECUTED;

    // if the token is 0, it's ethereum
    if (req.token == ERC20(0)) {
      req.destination.transfer(req.value);
    } else {
      req.token.transfer(req.destination, req.value);
    }

    RequestUpdate(id, req.state);
  }
}
