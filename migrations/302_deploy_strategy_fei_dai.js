// ============ Contracts ============

const Controller = artifacts.require('Controller')
const StrategyFeiDai = artifacts.require('StrategyFeiDai')
const VaultFeiDai = artifacts.require('VaultFeiDai')
const TokenMaster = artifacts.require('TokenMaster')

// ============ Main Migration ============

const migration = async (deployer, network, accounts) => {
  await Promise.all([
    deployStrategyFeiDai(deployer, network),
  ]);
};

module.exports = migration;

// ============ Deploy Functions ============

async function deployStrategyFeiDai(deployer, network) {
  const controller = await Controller.deployed();

  await deployer.deploy(
    StrategyFeiDai,
    controller.address
  )

  const vault = await VaultFeiDai.deployed();
  const strategy = await StrategyFeiDai.deployed()

  await controller.setStrategy(vault.address, strategy.address)
}
