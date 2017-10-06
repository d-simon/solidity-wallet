pragma solidity >= 0.4.15;
import 'zeppelin/token/StandardToken.sol';
import 'zeppelin/token/LimitedTransferToken.sol';
import 'zeppelin/math/SafeMath.sol';
import 'zeppelin/ownership/Ownable.sol';

contract ReputationToken is StandardToken, LimitedTransferToken, Ownable {

  string constant public name = "Reputation";
  string constant public symbol = "FREP";
  uint8 constant public decimals = 2;

  mapping (address => uint) public blocked;

  function inflate(address recipient, uint amount)
  onlyOwner {
    balances[recipient] = balances[recipient].add(amount);
    totalSupply += amount;
    Transfer(0, recipient, amount);
  }

  function burn(address recipient, uint amount)
  onlyOwner {
    if(amount > balances[recipient]) {
      totalSupply -= balances[recipient];
      Transfer(recipient, 0, balances[recipient]);
      balances[recipient] = 0;
    } else {
      balances[recipient] = balances[recipient].sub(amount);
      totalSupply -= amount;
      Transfer(recipient, 0, amount);
    }
  }

  function blockTokens(address recipient, uint amount)
  onlyOwner {
    blocked[recipient] = blocked[recipient].add(amount);
  }

  function unblockTokens(address recipient, uint amount)
  onlyOwner {
    blocked[recipient] = blocked[recipient].sub(amount);
  }

  function transferableTokens(address holder, uint64 time) public constant returns (uint256) {
    return balanceOf(holder).sub(blocked[holder]);
  }

}
