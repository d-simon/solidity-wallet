pragma solidity ^0.4.4;

import './Wallet.sol';

// Regarding Proxies:
// At this point it makes sense wait for an "update-framework" (by zeppelin?)
// Such a framework is probably going to be released in the near future
// after the byzantium release (hard-fork).

contract WalletProxy {

  // the owner needs to be defined before wallet because
  // we need the EXACT SAME storage layout
  address public owner;
  // Alternatively you could save it to a very high storage location (see WalletProxySafe)

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

// Alternatively you use a direct store address to avoid problems with the storage (wallet variable)
contract WalletProxySafe {
  // the owner needs to be defined first
  // because we need the same storage layout as the proxied contract (Wallet is Ownable)
  address public owner;

  function WalletProxy(address _target) {
    owner = msg.sender;
    // Here we store the wallet address into a very high memory address that
    // is highly unlikely to get used.
    assembly {
      sstore(0xfffffffffffffffffffffffffffffffffffffffff, _target)
    }
  }

  function() payable {
    address tgt;
    // Here we restore the wallet address directly from memory
    assembly {
     tgt := sload(0xfffffffffffffffffffffffffffffffffffffffff)
    }
    require(tgt.delegatecall(msg.data));
  }

  function __upgrade(address _next) {
    require(msg.sender == owner);
    // Here update the address in memory
    assembly {
      sstore(0xfffffffffffffffffffffffffffffffffffffffff, _next)
    }
  }
}
