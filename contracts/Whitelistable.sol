pragma solidity >= 0.4.15;

import 'zeppelin/ownership/Ownable.sol';

contract Whitelistable is Ownable {
  event Whitelisted(address indexed addr, bool value);

  mapping (address => bool) public whitelisted;

  modifier onlyWhitelisted {
    require(whitelisted[msg.sender] == true);
    _;
  }

  function setWhitelisted(address addr, bool value)
  onlyOwner {
    whitelisted[addr] = value;
    Whitelisted(addr, value);
  }
}
