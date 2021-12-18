import { Wallet, Contract } from 'ethers'
import { Web3Provider } from 'ethers/providers'
import { deployContract } from 'ethereum-waffle'
import { expandTo18Decimals } from './utilities'

import ERC20Mock from '../../build/contracts/ERC20Mock.json'
import DAO from '../../build/contracts/DAO.json'
import Treasury from '../../build/contracts/Treasury.json'
import Controller from '../../build/contracts/Controller.json'
import VaultFeiDai from '../../build/contracts/RewardVault.json'
import StrategyFeiDai from '../../build/contracts/StrategyFeiDai.json'


const overrides = {
    gasLimit: 9999999
}


interface Fixture {
    treasury: Contract
    dao: Contract
    controller: Contract
    vault: Contract
    strategyFeiDai: Contract
    fei: Contract
    dai: Contract
    tribe: Contract
}


export async function getFixture(provider: Web3Provider, [wallet]: Wallet[]): Promise<Fixture> {
    // deploy tokens
    const fei = await deployContract(wallet, ERC20Mock, ["Fei Protocol", "Fei"])
    const dai = await deployContract(wallet, ERC20Mock, ["MakerDAO Dai", "Dai"])
    const tribe = await deployContract(wallet, ERC20Mock, ["Fei Tribe", "Tribe"])
    const treasury = await deployContract(wallet, Treasury)
    const dao = await deployContract(wallet, DAO, [dai.address, expandTo18Decimals(1), 20000, [wallet.address]])
    const controller = await deployContract(wallet, Controller)
    let block = await provider.getBlock('latest')

    const vault = await deployContract(wallet, VaultFeiDai, [dai.address,  tribe.address, controller.address, '0x0'], overrides)
    const strategyFeiDai = await deployContract(wallet, StrategyFeiDai, [controller.address, dai.address, tribe.address],overrides )


    return {
        treasury,
        dao,
        controller,
        vault,
        strategyFeiDai,
        fei,
        dai,
        tribe
    }
}
