import {
    VaultProtocolOneCoinContract, VaultProtocolOneCoinInstance,
    VaultPoolTokenContract, VaultPoolTokenInstance,
    PoolContract, PoolInstance,
    TestErc20Contract, TestErc20Instance,
    VaultSavingsModuleContract, VaultSavingsModuleInstance,
    VaultStrategyStubContract, VaultStrategyStubInstance
} from '../../../types/truffle-contracts/index';

// tslint:disable-next-line:no-var-requires
const { BN, constants, expectEvent, shouldFail, time } = require('@openzeppelin/test-helpers');
// tslint:disable-next-line:no-var-requires
import Snapshot from '../../utils/snapshot';
const { expect, should } = require('chai');

const expectRevert = require('../../utils/expectRevert');
const expectEqualBN = require('../../utils/expectEqualBN');
const w3random = require('../../utils/w3random');

const ERC20 = artifacts.require('TestERC20');

const Pool = artifacts.require('Pool');
const VaultSavings = artifacts.require('VaultSavingsModule');
const VaultProtocol = artifacts.require('VaultProtocolOneCoin');
const VaultStrategy = artifacts.require('VaultStrategyStub');
const PoolToken = artifacts.require('VaultPoolToken');

contract('VaultProtocolOneCoin', async([ _, owner, user1, user2, user3, defiops, protocolStub, ...otherAccounts ]) => {

    let globalSnap: Snapshot;
    let vaultProtocol: VaultProtocolOneCoinInstance;
    let dai: TestErc20Instance;
    let usdc: TestErc20Instance;
    let busd: TestErc20Instance;
    let usdt: TestErc20Instance;
    let poolToken: VaultPoolTokenInstance;
    let pool: PoolInstance;
    let vaultSavings: VaultSavingsModuleInstance;
    let strategy: VaultStrategyStubInstance;


    before(async() => {
        //Deposit token 1
        dai = await ERC20.new({ from: owner });
        await (<any> dai).methods['initialize(string,string,uint8)']('DAI', 'DAI', 18, { from: owner });
        //Deposit token 2
        usdc = await ERC20.new({ from: owner });
        await (<any> usdc).methods['initialize(string,string,uint8)']('USDC', 'USDC', 18, { from: owner });

        await dai.transfer(user1, 1000, { from: owner });
        await dai.transfer(user2, 1000, { from: owner });
        await dai.transfer(user3, 1000, { from: owner });

        await usdc.transfer(user1, 1000, { from: owner });
        await usdc.transfer(user2, 1000, { from: owner });
        await usdc.transfer(user3, 1000, { from: owner });

        //------
        pool = await Pool.new({ from: owner });
        await (<any> pool).methods['initialize()']({ from: owner });
        //------
        vaultSavings = await VaultSavings.new({ from: owner });
        await (<any> vaultSavings).methods['initialize(address)'](pool.address, { from: owner });
        await vaultSavings.addDefiOperator(defiops, { from: owner });

        await pool.set('vault', vaultSavings.address, true, { from: owner });
        //------
        vaultProtocol = await VaultProtocol.new({ from: owner });
        await (<any> vaultProtocol).methods['initialize(address,address[])'](
            pool.address, [dai.address], { from: owner });
        await vaultProtocol.addDefiOperator(defiops, { from: owner });
        //------
        poolToken = await PoolToken.new({ from: owner });
        await (<any> poolToken).methods['initialize(address,string,string)'](
            pool.address, 'VaultSavings', 'VLT', { from: owner });

        await poolToken.addMinter(vaultSavings.address, { from: owner });
        await poolToken.addMinter(vaultProtocol.address, { from: owner });
        await poolToken.addMinter(defiops, { from: owner });
        //------
        strategy = await VaultStrategy.new({ from: owner });
        await (<any> strategy).methods['initialize(string)']('1', { from: owner });
        await strategy.setProtocol(protocolStub, { from: owner });

        await strategy.addDefiOperator(defiops, { from: owner });
        await strategy.addDefiOperator(vaultProtocol.address, { from: owner });
        //------
        await vaultProtocol.registerStrategy(strategy.address, { from: defiops });

        //------
        await vaultSavings.registerVault(vaultProtocol.address, poolToken.address, { from: owner });

        await vaultProtocol.setAvailableEnabled(true, { from: owner });

        globalSnap = await Snapshot.create(web3.currentProvider);
    });

    describe('Deposit into the vault', () => {

        afterEach(async() => await globalSnap.revert());

        it('Deposit single token into the vault', async() => {
            const before = {
                userBalance: await dai.balanceOf(user1),
                vaultBalance: await dai.balanceOf(vaultProtocol.address)
            };

            let onhold = await vaultProtocol.amountOnHold(user1, dai.address);
            expect(onhold.toNumber(), 'Deposit is not empty').to.equal(0);

            await dai.transfer(vaultProtocol.address, 10, { from: user1 });
            const depositResult = await (<any> vaultProtocol)
                .methods['depositToVault(address,address,uint256)'](user1, dai.address, 10, { from: defiops });

            expectEvent(depositResult, 'DepositToVault', { _user: user1, _token: dai.address, _amount: '10' });

            onhold = await vaultProtocol.amountOnHold(user1, dai.address);
            expect(onhold.toNumber(), 'Deposit was not set on-hold').to.equal(10);

            const after = {
                userBalance: await dai.balanceOf(user1),
                vaultBalance: await dai.balanceOf(vaultProtocol.address)
            };
            expect(after.vaultBalance.sub(before.vaultBalance).toNumber(), 'Tokens are not transferred to vault')
                .to.equal(10);
            expect(before.userBalance.sub(after.userBalance).toNumber(), 'Tokens are not transferred from user')
                .to.equal(10);
        });
    });
});