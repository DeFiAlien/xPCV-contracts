// ============ Contracts ============

const DAO = artifacts.require('DAO')
// ============ Main Migration ============

const migration = async (deployer, network, accounts) => {
  await Promise.all([
    setupContracts(deployer, network),
  ]);
};

module.exports = migration;

// ============ Deploy Functions ============

async function setupContracts(deployer, network) {
//   const dao = await DAO.deployed()

  console.log('finished')
}
