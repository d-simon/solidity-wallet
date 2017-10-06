pragma solidity >= 0.4.15;

import './zeppelin/ownership/Ownable.sol';

contract Whitelisted is Ownable {
  event WhitelistedSet(address indexed addr, bool value);

  mapping (address => bool) public whitelisted;

  modifier onlyWhitelisted {
    require(whitelisted[msg.sender] == true);
    _;
  }

  function setWhitelisted(address addr, bool value)
  onlyOwner {
    whitelisted[addr] = value;
    WhitelistedSet(addr, value);
  }
}
