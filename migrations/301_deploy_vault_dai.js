// ============ Contracts ============

const Controller = artifacts.require('Controller')
const VaultFeiDai = artifacts.require('VaultFeiDai')
const VaultTribe = artifacts.require('VaultTribe')


// ============ Main Migration ============

const migration = async (deployer, network, accounts) => {
  await Promise.all([
    deployVaultFeiDai(deployer, network),
  ]);
};

module.exports = migration;

// ============ Deploy Functions ============

async function deployVaultFeiDai(deployer, network) {
  const controller = await Controller.deployed();
  const vaultTribe = await VaultTribe.deployed();

  await deployer.deploy(
    VaultFeiDai,
    controller.address,
    vaultTribe.address,
  );
}
