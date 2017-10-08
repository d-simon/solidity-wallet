pragma solidity ^0.4.4;

import './Wallet.sol';

contract WalletProxy {

  // the owner needs to be defined before wallet because
  // we need the EXACT SAME storage layout
  address public owner;
  // Alternatively you could save it to a very high storage location
  // But we should wait for an "update-framework" (by zeppelin?)

  address public wallet; // this might cause a conflict with other variables (?)

  function WalletProxy(address wallet_instance) {
    owner = msg.sender;
    wallet = wallet_instance;
  }

  function ()
  payable {
    require(wallet.delegatecall(msg.data));
  }

  // the owner can update the code contract
  function __upgrade(address next) {
    require(msg.sender == owner);
    wallet = next;
  }
}
