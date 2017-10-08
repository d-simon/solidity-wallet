var WalletProxy = artifacts.require('./WalletProxy.sol');
var Wallet = artifacts.require('./Wallet.sol');

module.exports = function(deployer) {
  deployer.deploy(WalletProxy, Wallet.address);
};
