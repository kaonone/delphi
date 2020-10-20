import { expect } from 'chai';
import {
    VaultProtocolInstance,
    TestErc20Instance,
    VaultSavingsModuleInstance,
    VaultPoolTokenInstance,
    PoolInstance,
    AccessModuleInstance,
    VaultStrategyStubInstance,
} from '../../../types/truffle-contracts/index';
import Snapshot from '../../utils/snapshot';

const ERC20 = artifacts.require('TestERC20');
const VaultProtocol = artifacts.require('VaultProtocol');
const VaultSavings = artifacts.require('VaultSavingsModule');
const VaultStrategy = artifacts.require('VaultStrategyStub');
const PoolToken = artifacts.require('VaultPoolToken');
const Pool = artifacts.require('Pool');
const AccessModule = artifacts.require('AccessModule');

const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';

contract('VaultSavings Balances', async([ owner, user1, defiops, protocolStub ]) => {

    let globalSnap: Snapshot;
    let vault: VaultProtocolInstance;
    let vaultSavings: VaultSavingsModuleInstance;
    let poolToken: VaultPoolTokenInstance;
    let dai: TestErc20Instance;
    let usdc: TestErc20Instance;
    let busd: TestErc20Instance;
    let usdt: TestErc20Instance;
    let pool: PoolInstance;
    let accessModule: AccessModuleInstance;
    let strategy: VaultStrategyStubInstance;

    before(async() => {
        // Deposit token 1
        dai = await ERC20.new({ from: owner });
        await (<TestErc20Instance> dai).methods['initialize(string,string,uint8)']('DAI', 'DAI', 18, { from: owner });
        // Deposit token 2
        usdc = await ERC20.new({ from: owner });
        await (<TestErc20Instance> usdc).methods['initialize(string,string,uint8)']('USDC', 'USDC', 6, { from: owner });
        // Deposit token 3
        busd = await ERC20.new({ from: owner });
        await (<TestErc20Instance> busd).methods['initialize(string,string,uint8)']('BUSD', 'BUSD', 12,
            { from: owner });
        // Deposit token 4
        usdt = await ERC20.new({ from: owner });
        await (<TestErc20Instance> usdt).methods['initialize(string,string,uint8)']('BUSD', 'BUSD', 18,
            { from: owner });

        await dai.transfer(user1, 1000, { from: owner });
        await usdc.transfer(user1, 1000, { from: owner });
        await busd.transfer(user1, 1000, { from: owner });
        await usdt.transfer(user1, 1000, { from: owner });

        pool = await Pool.new({ from: owner });
        await (<PoolInstance> pool).methods['initialize()']({ from: owner });

        accessModule = await AccessModule.new({ from: owner });
        await accessModule.methods['initialize(address)'](pool.address, { from: owner });

        await pool.set('access', accessModule.address, true, { from: owner });

        vaultSavings = await VaultSavings.new({ from: owner });

        await (<VaultSavingsModuleInstance> vaultSavings).methods['initialize(address)'](pool.address, { from: owner });

        await vaultSavings.addVaultOperator(defiops, { from: owner });

        await pool.set('vault', vaultSavings.address, true, { from: owner });

        vault = await VaultProtocol.new({ from: owner });
        await (<VaultProtocolInstance> vault).methods['initialize(address,address[])'](
            pool.address, [dai.address, usdc.address, busd.address, usdt.address], { from: owner });
        await vault.addDefiOperator(vaultSavings.address, { from: owner });
        await vault.addDefiOperator(defiops, { from: owner });

        poolToken = await PoolToken.new({ from: owner });
        await (<VaultPoolTokenInstance> poolToken).methods['initialize(address,string,string)'](
            pool.address, 'VaultSavings', 'VLT', { from: owner });

        await poolToken.addMinter(vaultSavings.address, { from: owner });
        await poolToken.addMinter(vault.address, { from: owner });
        await poolToken.addMinter(defiops, { from: owner });

        strategy = await VaultStrategy.new({ from: owner });
        await (<VaultStrategyStubInstance> strategy).methods['initialize(string)']('1', { from: owner });
        await strategy.setProtocol(protocolStub, { from: owner });

        await strategy.addDefiOperator(defiops, { from: owner });
        await strategy.addDefiOperator(vault.address, { from: owner });

        await vault.registerStrategy(strategy.address, { from: defiops });
        await vault.setQuickWithdrawStrategy(strategy.address, { from: defiops });
        await vault.setAvailableEnabled(true, { from: owner });

        await vaultSavings.registerVault(vault.address, poolToken.address, { from: owner });

        globalSnap = await Snapshot.create(web3.currentProvider);
    });

    describe('Test balances', () => {

        const amounts = { dai: 10, usdc: 15, busd: 5, usdt: 25 };
        const decimals = { dai: 18, usdc: 6, busd: 12, usdt: 18 };
        const amountsNormalized = {
            dai: normalize(amounts.dai, decimals.dai),
            usdc: normalize(amounts.usdc, decimals.usdc),
            busd: normalize(amounts.busd, decimals.busd),
            usdt: normalize(amounts.usdt, decimals.usdt),
        };
        const totalAmountFull = Object.values(amountsNormalized).reduce((acc, x) => acc += x);

        function normalize(amount: number, decimals: number) {
            if (decimals < 18) {
                return amount * 10 ** (18 - decimals);
            } else if (decimals > 18) {
                return amount / 10 ** (decimals - 18);
            } else {
                return amount;
            }
        }

        beforeEach(async() => {
            await dai.approve(strategy.address, 1000, { from: protocolStub });
            await usdc.approve(strategy.address, 1000, { from: protocolStub });
            await busd.approve(strategy.address, 1000, { from: protocolStub });
            await usdt.approve(strategy.address, 1000, { from: protocolStub });

            await dai.approve(vaultSavings.address, 1000, { from: user1 });
            await usdc.approve(vaultSavings.address, 1000, { from: user1 });
            await busd.approve(vaultSavings.address, 1000, { from: user1 });
            await usdt.approve(vaultSavings.address, 1000, { from: user1 });

            globalSnap = await Snapshot.create(web3.currentProvider);
        });

        afterEach(async() => await globalSnap.revert());

        describe('Deposit', () => {

            it('Deposit to vault', async() => {
                const before = {
                    vault: {
                        normalizedBalance: await vault.methods['normalizedBalance()'].call(),
                        normalizedBalanceUser: await vault.methods['normalizedBalance(address)'].call(strategy.address),
                        normalizedVaultBalance: await vault.normalizedVaultBalance(),
                    },
                    strategy: {
                        balanceOf: {
                            dai: await strategy.balanceOf.call(dai.address),
                            usdc: await strategy.balanceOf.call(usdc.address),
                            busd: await strategy.balanceOf.call(busd.address),
                            usdt: await strategy.balanceOf.call(usdt.address),
                        },
                        balanceOfAll: (await strategy.balanceOfAll.call()).map(x => x.toNumber()),
                    },
                    poolToken: await poolToken.balanceOf(user1),
                };

                expect(before.strategy.balanceOfAll, 'No tokens on the strategy before deposit').to.eql([0, 0, 0, 0]);

                /***********************
                 * 1. Deposit to vault *
                 **********************/
                await (<VaultSavingsModuleInstance>vaultSavings).methods['deposit(address,address[],uint256[])'](
                    vault.address, [dai.address, usdc.address, busd.address, usdt.address],
                    Object.values(amounts), { from: user1 });

                const afterDeposit = {
                    vault: {
                        normalizedBalance: await vault.methods['normalizedBalance()'].call(),
                        normalizedBalanceUser: await vault.methods['normalizedBalance(address)'].call(strategy.address),
                        normalizedVaultBalance: await vault.normalizedVaultBalance(),
                    },
                    strategy: {
                        balanceOf: {
                            dai: await strategy.balanceOf.call(dai.address),
                            usdc: await strategy.balanceOf.call(usdc.address),
                            busd: await strategy.balanceOf.call(busd.address),
                            usdt: await strategy.balanceOf.call(usdt.address),
                        },
                        balanceOfAll: (await strategy.balanceOfAll.call()).map(x => x.toNumber()),
                    },
                    poolToken: await poolToken.balanceOf(user1),
                };

                expect(afterDeposit.vault.normalizedBalance.sub(before.vault.normalizedBalance).toNumber(),
                    'Total normalized strategy balance should not have changed').to.equal(0);
                expect(afterDeposit.vault.normalizedBalanceUser.sub(before.vault.normalizedBalanceUser).toNumber(),
                    'A strategy\'s normalized balance should not have changed').to.equal(0);
                expect(afterDeposit.vault.normalizedVaultBalance.sub(before.vault.normalizedVaultBalance).toNumber(),
                    'Normalized vault balance should change correctly').to.equal(totalAmountFull);

                expect(afterDeposit.strategy.balanceOf.dai.sub(before.strategy.balanceOf.dai).toNumber(),
                    'Strategy DAI balance should not change').to.equal(0);
                expect(afterDeposit.strategy.balanceOf.usdc.sub(before.strategy.balanceOf.usdc).toNumber(),
                    'Strategy USDC balance should not change').to.equal(0);
                expect(afterDeposit.strategy.balanceOf.busd.sub(before.strategy.balanceOf.busd).toNumber(),
                    'Strategy BUSD balance should not change').to.equal(0);
                expect(afterDeposit.strategy.balanceOf.usdt.sub(before.strategy.balanceOf.usdt).toNumber(),
                    'Strategy USDT balance should not change').to.equal(0);

                expect(afterDeposit.poolToken.sub(before.poolToken).toNumber(),
                    'User pool token balance was not changed correctly').to.equal(totalAmountFull);

                expect(afterDeposit.strategy.balanceOfAll, 'No tokens on the strategy after deposit')
                    .to.eql([0, 0, 0, 0]);

                /***********************
                 * 2. Move to strategy *
                 **********************/
                await vaultSavings.handleOperatorActions(vault.address, strategy.address, ZERO_ADDRESS,
                    { from: defiops });

                const afterOperator = {
                    vault: {
                        normalizedBalance: await vault.methods['normalizedBalance()'].call(),
                        normalizedBalanceUser: await vault.methods['normalizedBalance(address)'].call(strategy.address),
                        normalizedVaultBalance: await vault.normalizedVaultBalance(),
                    },
                    strategy: {
                        balanceOf: {
                            dai: await strategy.balanceOf.call(dai.address),
                            usdc: await strategy.balanceOf.call(usdc.address),
                            busd: await strategy.balanceOf.call(busd.address),
                            usdt: await strategy.balanceOf.call(usdt.address),
                        },
                        balanceOfAll: (await strategy.balanceOfAll.call()).map(x => x.toNumber()),
                    },
                    poolToken: await poolToken.balanceOf(user1),
                };

                expect(afterOperator.vault.normalizedBalance.sub(afterDeposit.vault.normalizedBalance).toNumber(),
                    'Total normalized strategy balance should change correctly').to.equal(totalAmountFull);
                expect(afterOperator.vault.normalizedBalanceUser.sub(afterDeposit.vault.normalizedBalanceUser)
                    .toNumber(), 'A strategy\'s normalized balance should change correctly').to.equal(totalAmountFull);
                expect(afterDeposit.vault.normalizedVaultBalance.sub(afterOperator.vault.normalizedVaultBalance)
                    .toNumber(), 'Normalized vault balance should change correctly after moving to strategy')
                    .to.equal(totalAmountFull);

                expect(afterOperator.strategy.balanceOf.dai.sub(afterDeposit.strategy.balanceOf.dai).toNumber(),
                    'Strategy DAI balance should change correctly').to.equal(amounts.dai);
                expect(afterOperator.strategy.balanceOf.usdc.sub(afterDeposit.strategy.balanceOf.usdc).toNumber(),
                    'Strategy USDC balance should change correctly').to.equal(amounts.usdc);
                expect(afterOperator.strategy.balanceOf.busd.sub(afterDeposit.strategy.balanceOf.busd).toNumber(),
                    'Strategy BUSD balance should change correctly').to.equal(amounts.busd);
                expect(afterOperator.strategy.balanceOf.usdt.sub(afterDeposit.strategy.balanceOf.usdt).toNumber(),
                    'Strategy USDT balance should change correctly').to.equal(amounts.usdt);

                expect(afterOperator.poolToken.toNumber(), 'User pool token balance should not change')
                    .to.equal(afterDeposit.poolToken.toNumber());

                expect(afterOperator.strategy.balanceOfAll, 'Strategy balance should change correctly after operator')
                    .to.eql(Object.values(amounts));
            });

        });

        describe('Withdraw', () => {

            let localSnap: Snapshot;

            beforeEach(async() => {
                // Deposit to vault
                await (<VaultSavingsModuleInstance>vaultSavings).methods['deposit(address,address[],uint256[])'](
                    vault.address, [dai.address, usdc.address, busd.address, usdt.address],
                    Object.values(amounts), { from: user1 });
                // Move to strategy
                await vaultSavings
                    .handleOperatorActions(vault.address, strategy.address, ZERO_ADDRESS, { from: defiops });

                localSnap = await Snapshot.create(web3.currentProvider);
            });

            afterEach(async() => await localSnap.revert());

            it('Withdraw to vault', async() => {
                const before = {
                    vault: {
                        normalizedBalance: await vault.methods['normalizedBalance()'].call(),
                        normalizedBalanceUser: await vault.methods['normalizedBalance(address)'].call(strategy.address),
                        normalizedVaultBalance: await vault.normalizedVaultBalance(),
                        dai: await dai.balanceOf(vault.address),
                        usdc: await usdc.balanceOf(vault.address),
                        busd: await busd.balanceOf(vault.address),
                        usdt: await usdt.balanceOf(vault.address),
                    },
                    strategy: {
                        balanceOf: {
                            dai: await strategy.balanceOf.call(dai.address),
                            usdc: await strategy.balanceOf.call(usdc.address),
                            busd: await strategy.balanceOf.call(busd.address),
                            usdt: await strategy.balanceOf.call(usdt.address),
                        },
                        balanceOfAll: (await strategy.balanceOfAll.call()).map(x => x.toNumber()),
                    },
                    poolToken: await poolToken.balanceOf(user1),
                };

                /*******************
                 * 3. Withdraw DAI *
                 ******************/
                await (<VaultSavingsModuleInstance>vaultSavings)
                    .withdraw(vault.address, [dai.address],
                        [amounts.dai], false, { from: user1 });
                await vaultSavings
                    .handleOperatorActions(vault.address, strategy.address, ZERO_ADDRESS, { from: defiops });
                await vaultSavings.clearProtocolStorage(vault.address, { from: defiops });

                const afterWithdraw = {
                    vault: {
                        normalizedBalance: await vault.methods['normalizedBalance()'].call(),
                        normalizedBalanceUser: await vault.methods['normalizedBalance(address)'].call(strategy.address),
                        normalizedVaultBalance: await vault.normalizedVaultBalance(),
                        dai: await dai.balanceOf(vault.address),
                        usdc: await usdc.balanceOf(vault.address),
                        busd: await busd.balanceOf(vault.address),
                        usdt: await usdt.balanceOf(vault.address),
                    },
                    strategy: {
                        balanceOf: {
                            dai: await strategy.balanceOf.call(dai.address),
                            usdc: await strategy.balanceOf.call(usdc.address),
                            busd: await strategy.balanceOf.call(busd.address),
                            usdt: await strategy.balanceOf.call(usdt.address),
                        },
                        balanceOfAll: (await strategy.balanceOfAll.call()).map(x => x.toNumber()),
                    },
                    poolToken: await poolToken.balanceOf(user1),
                };

                expect(before.vault.normalizedBalance.sub(afterWithdraw.vault.normalizedBalance).toNumber(),
                    'Total normalized strategy balance should change correctly').to.equal(amounts.dai);
                expect(before.vault.normalizedBalanceUser.sub(afterWithdraw.vault.normalizedBalanceUser)
                    .toNumber(), 'A strategy\'s normalized balance should change correctly').to.equal(amounts.dai);
                expect(afterWithdraw.vault.normalizedVaultBalance.sub(before.vault.normalizedVaultBalance)
                    .toNumber(), 'Normalized vault balance should change correctly after moving to strategy')
                    .to.equal(amounts.dai);

                expect(afterWithdraw.vault.dai.sub(before.vault.dai).toNumber(),
                    'Vault DAI balance should change correctly').to.equal(amounts.dai);
                expect(before.vault.usdc.toNumber(), 'Vault USDC balance should not change')
                    .to.equal(afterWithdraw.vault.usdc.toNumber());
                expect(before.vault.busd.toNumber(), 'Vault BUSD balance should not change')
                    .to.equal(afterWithdraw.vault.busd.toNumber());
                expect(before.vault.usdt.toNumber(), 'Vault USDT balance should not change')
                    .to.equal(afterWithdraw.vault.usdt.toNumber());

                expect(before.strategy.balanceOf.dai.sub(afterWithdraw.strategy.balanceOf.dai).toNumber(),
                    'Strategy DAI balance should change correctly').to.equal(amounts.dai);
                expect(before.strategy.balanceOf.usdc.toNumber(), 'Strategy DAI balance should not change')
                    .to.equal(afterWithdraw.strategy.balanceOf.usdc.toNumber());
                expect(before.strategy.balanceOf.busd.toNumber(), 'Strategy BUSD balance should not change')
                    .to.equal(afterWithdraw.strategy.balanceOf.busd.toNumber());
                expect(before.strategy.balanceOf.usdt.toNumber(), 'Strategy USDT balance should not change')
                    .to.equal(afterWithdraw.strategy.balanceOf.usdt.toNumber());

                expect(before.poolToken.sub(afterWithdraw.poolToken).toNumber(),
                    'User pool token balance should change correctly').to.equal(10);

                expect(afterWithdraw.strategy.balanceOfAll, 'Strategy balance should change correctly after withdrawal')
                    .to.eql([0, ...Object.values(amounts).slice(1)]); // [ 0, 15, 5, 25 ]

                /**************************
                 * 4. Withdraw everything *
                 *************************/
                await (<VaultSavingsModuleInstance>vaultSavings)
                    .withdraw(vault.address, [usdc.address, busd.address, usdt.address],
                        [amounts.usdc, amounts.busd, amounts.usdt], false, { from: user1 });
                await vaultSavings
                    .handleOperatorActions(vault.address, strategy.address, ZERO_ADDRESS, { from: defiops });
                await vaultSavings.clearProtocolStorage(vault.address, { from: defiops });

                const afterWithdrawEvr = {
                    vault: {
                        normalizedBalance: await vault.methods['normalizedBalance()'].call(),
                        normalizedBalanceUser: await vault.methods['normalizedBalance(address)'].call(strategy.address),
                        normalizedVaultBalance: await vault.normalizedVaultBalance(),
                        dai: await dai.balanceOf(vault.address),
                        usdc: await usdc.balanceOf(vault.address),
                        busd: await busd.balanceOf(vault.address),
                        usdt: await usdt.balanceOf(vault.address),
                    },
                    strategy: {
                        balanceOf: {
                            dai: await strategy.balanceOf.call(dai.address),
                            usdc: await strategy.balanceOf.call(usdc.address),
                            busd: await strategy.balanceOf.call(busd.address),
                            usdt: await strategy.balanceOf.call(usdt.address),
                        },
                        balanceOfAll: (await strategy.balanceOfAll.call()).map(x => x.toNumber()),
                    },
                    poolToken: await poolToken.balanceOf(user1),
                };

                expect(afterWithdrawEvr.vault.normalizedVaultBalance.toNumber(),
                    'Normalized vault balance should be correct').to.equal(totalAmountFull);
                expect(afterWithdrawEvr.poolToken.toNumber(), 'Pool token balance should be zero')
                    .to.equal(0);

                expect(afterWithdrawEvr.strategy.balanceOf.dai.toNumber(), 'Strategy should have no DAI').to.equal(0);
                expect(afterWithdrawEvr.strategy.balanceOf.usdc.toNumber(), 'Strategy should have no USDC').to.equal(0);
                expect(afterWithdrawEvr.strategy.balanceOf.busd.toNumber(), 'Strategy should have no BUSD').to.equal(0);
                expect(afterWithdrawEvr.strategy.balanceOf.usdt.toNumber(), 'Strategy should have no USDT').to.equal(0);
                expect(afterWithdrawEvr.strategy.balanceOfAll, 'Strategy balance should be zero for all tokens')
                    .to.eql([0, 0, 0, 0]);

                expect(afterWithdrawEvr.vault.dai.toNumber(), 'Vault DAI balance should be correct')
                    .to.equal(amounts.dai);
                expect(afterWithdrawEvr.vault.usdc.toNumber(), 'Vault USDC balance should be correct')
                    .to.equal(amounts.usdc);
                expect(afterWithdrawEvr.vault.busd.toNumber(), 'Vault BUSD balance should be correct')
                    .to.equal(amounts.busd);
                expect(afterWithdrawEvr.vault.usdt.toNumber(), 'Vault USDT balance should be correct')
                    .to.equal(amounts.usdt);

                expect(afterWithdrawEvr.vault.normalizedBalance.toNumber(),
                    'Total normalized strategy balance should be zero').to.equal(0);
                expect(afterWithdrawEvr.vault.normalizedBalanceUser.toNumber(),
                    'A strategy\'s normalized balance should be zero').to.equal(0);
            });

        });

    });

});
