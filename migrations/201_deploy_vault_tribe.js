// ============ Contracts ============

const Controller = artifacts.require('Controller')
const VaultTribe= artifacts.require('VaultTribe')

// ============ Main Migration ============

const migration = async (deployer, network, accounts) => {
  await Promise.all([
    deployVaultTribe(deployer, network),
  ]);
};

module.exports = migration;

// ============ Deploy Functions ============

async function deployVaultTribe(deployer, network) {
  const controller = await Controller.deployed();

  await deployer.deploy(
    VaultTribe,
    controller.address,
    '0x6B175474E89094C44Da98b954EedeAC495271d0F' // dai
  );
}
