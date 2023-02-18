const Oracle = artifacts.require("Oracle");
const House = artifacts.require("House");
const Bet5050 = artifacts.require("Bet5050");

module.exports = function (deployer, network, accounts) {
  deployer.deploy(Oracle).then(function () {
      return deployer.deploy(Bet5050);
  });
};
