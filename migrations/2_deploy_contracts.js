var Wallet = artifacts.require('./Wallet.sol');
var ReputationToken = artifacts.require('./ReputationToken.sol');

module.exports = function(deployer) {
  deployer.deploy(Wallet);
  deployer.deploy(ReputationToken);
};
