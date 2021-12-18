// ============ Contracts ============

const Controller = artifacts.require('Controller')
const StrategyTribe = artifacts.require('StrategyTribe')
const VaultTribe = artifacts.require('VaultTribe')

// ============ Main Migration ============

const migration = async (deployer, network, accounts) => {
  await Promise.all([
    deployStrategyTribe(deployer, network),
  ]);
};

module.exports = migration;

// ============ Deploy Functions ============

async function deployStrategyTribe(deployer, network) {
  const controller = await Controller.deployed();

  await deployer.deploy(
    StrategyTribe,
    controller.address
  )

  const vault = await VaultTribe.deployed();
  const strategy = await StrategyTribe.deployed()

  await controller.setStrategy(vault.address, strategy.address)
}
