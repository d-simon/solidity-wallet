// // Theoretically you could run a third migration and inflate some balances
// var Wallet = artifacts.require("./Wallet.sol");
// var ReputationToken = artifacts.require("./ReputationToken.sol");
//
// module.exports = function(deployer) {
//   // deployer.deploy(Wallet);
//   Promise.all([
//     Wallet.deployed(),
//     ReputationToken.deployed()
//   ]).then(([wallet, rep]) => {
//     rep.inflate(wallet.address, 10000);
//   });
// };

module.exports = function(deployer) {};
