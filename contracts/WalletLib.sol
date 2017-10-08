pragma solidity ^0.4.4;

import 'zeppelin/token/ERC20.sol';

library WalletLib {
  /*string constant public contract_version = "0.1._";*/

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
  event RequestUpdate(uint indexed id, uint state);
  // Fired when the spending_limit is updated
  event SpendingLimitUpdated(address indexed addr, uint value);

  modifier checkRequest (Request storage request, address destination, uint value, uint timestamp, address token, RequestState expected) {
    require(request.state == expected);
    require(request.destination == destination);
    require(request.value == value);
    require(request.token == token);
    require(request.timestamp == timestamp);
    _;
  }

  // This creates a new request. Fires the RequestAdded event. Id should
  // increase by one. Initial state is PENDING.
  function request(Request[] storage transfer_requests, address destination, uint value, uint timestamp, address token) {
    transfer_requests.push(Request({
      sender: msg.sender,
      destination: destination,
      value: value,
      state: RequestState.PENDING,
      timestamp: timestamp,
      token: ERC20(token)
    }));
    RequestAdded(transfer_requests.length - 1, msg.sender);
  }

  function updateStatus(Request[] storage transfer_requests, uint id, RequestState state)
  internal {
    Request storage req = transfer_requests[id];
    req.state = state;
    RequestUpdate(id, uint(req.state));
  }

  // Can only be called by the owner. Checks destination and value. (Because the chain organisation)
  // State changes to APPROVED.
  function approve(Request[] storage transfer_requests, uint id, address destination, uint value, uint timestamp, address token)
  checkRequest(transfer_requests[id], destination, value, timestamp, token, RequestState.PENDING) {
    updateStatus(transfer_requests, id, RequestState.APPROVED);
  }

  // Can only be called by the owner. Checks destination and value.
  // State changes to REJECTED.
  function reject(Request[] storage transfer_requests, uint id, address destination, uint value, uint timestamp, address token)
  checkRequest(transfer_requests[id], destination, value, timestamp, token, RequestState.PENDING) {
    updateStatus(transfer_requests, id, RequestState.REJECTED);
  }


  // Can only be called by the sender. State needs to be APPROVED and becomes EXECUTED.
  // Ether are sent out to the destination.
  function execute(Request[] storage transfer_requests, uint id) {
    Request storage req = transfer_requests[id];
    require(msg.sender == req.sender);
    require(req.state == RequestState.APPROVED);
    require(now < req.timestamp);
    updateStatus(transfer_requests, id, RequestState.EXECUTED);

    // if the token is 0, it's ethereum
    if (req.token == ERC20(0)) {
      req.destination.transfer(req.value);
    } else {
      require(req.token.transfer(req.destination, req.value)); //
    }

  }
}
