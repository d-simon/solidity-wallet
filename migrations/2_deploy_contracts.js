var Wallet = artifacts.require('./Wallet.sol');
var WalletLib = artifacts.require('./WalletLib.sol');
var ReputationToken = artifacts.require('./ReputationToken.sol');

module.exports = function(deployer) {
  deployer.deploy(WalletLib);
  deployer.link(WalletLib, Wallet);
  deployer.deploy(Wallet);
  deployer.deploy(ReputationToken);
};
