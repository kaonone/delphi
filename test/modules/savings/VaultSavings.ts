import {
    VaultProtocolContract, VaultProtocolInstance,
    TestErc20Contract, TestErc20Instance,
    VaultSavingsModuleContract, VaultSavingsModuleInstance,
    VaultPoolTokenContract, VaultPoolTokenInstance,
    PoolContract, PoolInstance,
    AccessModuleContract, AccessModuleInstance,
    VaultStrategyStubContract, VaultStrategyStubInstance
} from '../../../types/truffle-contracts/index';

// tslint:disable-next-line:no-var-requires
const { BN, constants, expectEvent, shouldFail, time } = require('@openzeppelin/test-helpers');
// tslint:disable-next-line:no-var-requires
import Snapshot from '../../utils/snapshot';
const { expect, should } = require('chai');

const expectRevert= require('../../utils/expectRevert');
const expectEqualBN = require('../../utils/expectEqualBN');
const w3random = require('../../utils/w3random');
const advanceBlockAtTime = require('../../utils/advanceBlockAtTime');

const ERC20 = artifacts.require('TestERC20');

const VaultProtocol = artifacts.require('VaultProtocol');
const VaultSavings = artifacts.require('VaultSavingsModule');
const VaultStrategy = artifacts.require('VaultStrategyStub');
const PoolToken = artifacts.require('VaultPoolToken');
const Pool = artifacts.require('Pool');
const AccessModule = artifacts.require('AccessModule');

contract('VaultSavings', async([ _, owner, user1, user2, user3, defiops, protocolStub, ...otherAccounts ]) => {

    let globalSnap: Snapshot;
    let vaultProtocol: VaultProtocolInstance;
    let vaultSavings: VaultSavingsModuleInstance;
    let poolToken: VaultPoolTokenInstance;
    let dai: TestErc20Instance;
    let usdc: TestErc20Instance;
    let busd: TestErc20Instance;
    let pool: PoolInstance;
    let accessModule: AccessModuleInstance;
    let strategy: VaultStrategyStubInstance;

    const blockTimeTravel = async(delta: BN) => {
        const block1 = await web3.eth.getBlock('pending');
        const tm = new BN(block1.timestamp);
        await advanceBlockAtTime(tm.add(delta).add(new BN(5)).toNumber());
    };

    before(async() => {
        //Deposit token 1
        dai = await ERC20.new({ from: owner });
        await (<any> dai).methods['initialize(string,string,uint8)']('DAI', 'DAI', 18, { from: owner });
        //Deposit token 2
        usdc = await ERC20.new({ from: owner });
        await (<any> usdc).methods['initialize(string,string,uint8)']('USDC', 'USDC', 18, { from: owner });
        //Deposit token 3
        busd = await ERC20.new({ from: owner });
        await (<any> busd).methods['initialize(string,string,uint8)']('BUSD', 'BUSD', 18, { from: owner });

        await dai.transfer(user1, 1000, { from: owner });
        await dai.transfer(user2, 1000, { from: owner });
        await dai.transfer(user3, 1000, { from: owner });

        await usdc.transfer(user1, 1000, { from: owner });
        await usdc.transfer(user2, 1000, { from: owner });
        await usdc.transfer(user3, 1000, { from: owner });

        await busd.transfer(user1, 1000, { from: owner });
        await busd.transfer(user2, 1000, { from: owner });
        await busd.transfer(user3, 1000, { from: owner });
        //------
        pool = await Pool.new({ from: owner });
        await (<any> pool).methods['initialize()']({ from: owner });
        //------
        accessModule = await AccessModule.new({ from: owner });
        await accessModule.methods['initialize(address)'](pool.address, { from: owner });

        await pool.set('access', accessModule.address, true, { from: owner });
        //------
        vaultSavings = await VaultSavings.new({ from: owner });
        await (<any> vaultSavings).methods['initialize(address)'](pool.address, { from: owner });
        await vaultSavings.addDefiOperator(defiops, { from: owner });

        await pool.set('vault', vaultSavings.address, true, { from: owner });
        //------
        vaultProtocol = await VaultProtocol.new({ from: owner });
        await (<any> vaultProtocol).methods['initialize(address,address[])'](
            pool.address, [dai.address, usdc.address, busd.address], { from: owner });
        await vaultProtocol.addDefiOperator(vaultSavings.address, { from: owner });
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

        beforeEach(async() => {
            await dai.approve(vaultProtocol.address, 80, { from: user1 });
            await dai.approve(vaultProtocol.address, 50, { from: user2 });
        });

        afterEach(async() => await globalSnap.revert());

        it('User gets LP tokens after the deposit through VaultSavings', async() => {
            await (<any> vaultSavings).methods['deposit(address,address[],uint256[])'](
                vaultProtocol.address, [dai.address], [80], { from: user1 });

            const userPoolBalance = await poolToken.balanceOf(user1, { from: user1 });
            expect(userPoolBalance.toNumber(), 'Pool tokens are not minted for user1').to.equal(80);
        });

        it('Deposit through the VaultSavings goes to the Vault', async() => {
            const userBalanceBefore = await dai.balanceOf(user1, { from: user1 });

            await (<any> vaultSavings).methods['deposit(address,address[],uint256[])'](
                vaultProtocol.address, [dai.address], [80], { from: user1 });

            const vaultBalance = await dai.balanceOf(vaultProtocol.address, { from: owner });
            expect(vaultBalance.toNumber(), 'Tokens from (1) are not transferred to vault').to.equal(80);

            const userOnHold = await vaultProtocol.amountOnHold(user1, dai.address, { from: owner });
            expect(userOnHold.toNumber(), 'On-hold record for (1) was not created').to.equal(80);

            const userBalanceAfter = await dai.balanceOf(user1, { from: user1 });
            expect(userBalanceBefore.sub(userBalanceAfter).toNumber(), 'User (1) hasn\'t transfered tokens to vault')
                .to.equal(80);
        });

        it('LP tokens are marked as on-hold while being in the Vault', async() => {
            await (<any> vaultSavings).methods['deposit(address,address[],uint256[])'](
                vaultProtocol.address, [dai.address], [80], { from: user1 });
            await (<any> vaultSavings).methods['deposit(address,address[],uint256[])'](
                vaultProtocol.address, [dai.address], [50], { from: user2 });

            let onHoldPool = await poolToken.onHoldBalanceOf(user1, { from: owner });
            expect(onHoldPool.toNumber(), 'Pool tokens are not set on-hold for user (1)').to.equal(80);
            onHoldPool = await poolToken.onHoldBalanceOf(user2, { from: owner });
            expect(onHoldPool.toNumber(), 'Pool tokens are not set on-hold for user (2)').to.equal(50);
        });

        describe('Many tokens', async() => {

            let vault2: VaultProtocolInstance;
            let vault3: VaultProtocolInstance;
            let poolToken2: VaultPoolTokenInstance;
            let poolToken3: VaultPoolTokenInstance;

            beforeEach(async() => {
                vault2 = await VaultProtocol.new({ from: owner });
                await (<VaultProtocolInstance>vault2).methods['initialize(address,address[])'](
                    pool.address, [dai.address, usdc.address], { from: owner });
                await vault2.addDefiOperator(vaultSavings.address, { from: owner });
                await vault2.addDefiOperator(defiops, { from: owner });

                await vault2.setAvailableEnabled(true, { from: owner });

                vault3 = await VaultProtocol.new({ from: owner });
                await (<VaultProtocolInstance>vault3).methods['initialize(address,address[])'](
                    pool.address, [busd.address], { from: owner });
                await vault3.addDefiOperator(vaultSavings.address, { from: owner });
                await vault3.addDefiOperator(defiops, { from: owner });

                await vault3.setAvailableEnabled(true, { from: owner });

                poolToken2 = await PoolToken.new({ from: owner });
                await (<VaultPoolTokenInstance>poolToken2).methods['initialize(address,string,string)'](
                    pool.address, 'VaultSavings', 'VLT', { from: owner });
                await poolToken2.addMinter(vaultSavings.address, { from: owner });
                await poolToken2.addMinter(vaultProtocol.address, { from: owner });
                await poolToken2.addMinter(defiops, { from: owner });

                poolToken3 = await PoolToken.new({ from: owner });
                await (<VaultPoolTokenInstance>poolToken3).methods['initialize(address,string,string)'](
                    pool.address, 'VaultSavings', 'VLT', { from: owner });
                await poolToken3.addMinter(vaultSavings.address, { from: owner });
                await poolToken3.addMinter(vaultProtocol.address, { from: owner });
                await poolToken3.addMinter(defiops, { from: owner });

                await vaultSavings.registerVault(vault2.address, poolToken2.address, { from: owner });
                await vaultSavings.registerVault(vault3.address, poolToken3.address, { from: owner });
                await poolToken2.addMinter(vault2.address, { from: owner });
                await poolToken3.addMinter(vault3.address, { from: owner });
            });

            after(async() => await globalSnap.revert());

            it('User gets LP tokens after a deposit into multiple vaults', async() => {
                await dai.approve(vaultProtocol.address, 30, { from: user1 });
                await dai.approve(vault2.address, 50, { from: user1 });
                await busd.approve(vault3.address, 20, { from: user1 });

                const before = {
                    vault1Balance: await dai.balanceOf(vaultProtocol.address),
                    vault2Balance: await dai.balanceOf(vault2.address),
                    vault3Balance: await busd.balanceOf(vault3.address)
                };

                await (<VaultSavingsModuleInstance>vaultSavings).methods['deposit(address[],address[],uint256[])'](
                    [vaultProtocol.address, vault2.address, vault3.address],
                    [dai.address, dai.address, busd.address],
                    [30, 50, 20],
                    { from: user1 }
                );

                const after = {
                    vault1Balance: await dai.balanceOf(vaultProtocol.address),
                    vault2Balance: await dai.balanceOf(vault2.address),
                    vault3Balance: await busd.balanceOf(vault3.address)
                };
                const onHoldAmount = {
                    vault1: await vaultProtocol.amountOnHold(user1, dai.address),
                    vault2: await vault2.amountOnHold(user1, dai.address),
                    vault3: await vault3.amountOnHold(user1, busd.address)
                };
                const userPoolBalanceToken1 = await poolToken.balanceOf(user1, { from: user1 });
                const userPoolBalanceToken2 = await poolToken2.balanceOf(user1, { from: user1 });
                const userPoolBalanceToken3 = await poolToken3.balanceOf(user1, { from: user1 });

                expect((after.vault1Balance.sub(before.vault1Balance).toNumber()), "Incorrect deposit into Vault 1").to.equal(30);
                expect((after.vault2Balance.sub(before.vault2Balance).toNumber()), "Incorrect deposit into Vault 2").to.equal(50);
                expect((after.vault3Balance.sub(before.vault3Balance).toNumber()), "Incorrect deposit into Vault 3").to.equal(20);

                expect(onHoldAmount.vault1.toNumber(), "Tokens are not set on-hold in Vault 1").to.equal(30);
                expect(onHoldAmount.vault2.toNumber(), "Tokens are not set on-hold in Vault 2").to.equal(50);
                expect(onHoldAmount.vault3.toNumber(), "Tokens are not set on-hold in Vault 3").to.equal(20);

                expect(userPoolBalanceToken1.toNumber(), "Pool tokens (1) are not minted").to.equal(30);
                expect(userPoolBalanceToken2.toNumber(), "Pool tokens (2) are not minted").to.equal(50);
                expect(userPoolBalanceToken3.toNumber(), "Pool tokens (3) are not minted").to.equal(20);
            });

            it('User can deposit into all vault tokens', async() => {
                await dai.approve(vaultProtocol.address, 80, { from: user1 });
                await usdc.approve(vaultProtocol.address, 50, { from: user1 });
                await busd.approve(vaultProtocol.address, 100, { from: user1 });
                await dai.approve(vault2.address, 20, { from: user1 });
                await usdc.approve(vault2.address, 30, { from: user1 });
                await busd.approve(vault3.address, 90, { from: user1 });

                const before = {
                    vault1Balance: {
                        dai: await dai.balanceOf(vaultProtocol.address),
                        usdc: await usdc.balanceOf(vaultProtocol.address),
                        busd: await busd.balanceOf(vaultProtocol.address),
                    },
                    vault2Balance: {
                        dai: await dai.balanceOf(vault2.address),
                        usdc: await usdc.balanceOf(vault2.address),
                    },
                    vault3Balance: {
                        busd: await busd.balanceOf(vault3.address),
                    }
                };

                await (<any>vaultSavings).methods['depositAll(address[],address[],uint256[])'](
                    [vaultProtocol.address, vault2.address, vault3.address],
                    [dai.address, usdc.address, busd.address, dai.address, usdc.address, busd.address],
                    [80, 50, 100, 20, 30, 90],
                    { from: user1 }
                );

                const after = {
                    vault1Balance: {
                        dai: await dai.balanceOf(vaultProtocol.address),
                        usdc: await usdc.balanceOf(vaultProtocol.address),
                        busd: await busd.balanceOf(vaultProtocol.address),
                    },
                    vault2Balance: {
                        dai: await dai.balanceOf(vault2.address),
                        usdc: await usdc.balanceOf(vault2.address),
                    },
                    vault3Balance: {
                        busd: await busd.balanceOf(vault3.address),
                    }
                };
                const onHoldAmount = {
                    vault1: {
                        dai: await vaultProtocol.amountOnHold(user1, dai.address),
                        usdc: await vaultProtocol.amountOnHold(user1, usdc.address),
                        busd: await vaultProtocol.amountOnHold(user1, busd.address)
                    },
                    vault2: {
                        dai: await vault2.amountOnHold(user1, dai.address),
                        usdc: await vault2.amountOnHold(user1, usdc.address)
                    },
                    vault3: {
                        busd: await vault3.amountOnHold(user1, busd.address)
                    }
                };
                const userPoolBalanceToken1 = await poolToken.balanceOf(user1, { from: user1 });
                const userPoolBalanceToken2 = await poolToken2.balanceOf(user1, { from: user1 });
                const userPoolBalanceToken3 = await poolToken3.balanceOf(user1, { from: user1 });

                expect((after.vault1Balance.dai.sub(before.vault1Balance.dai).toNumber()), "Incorrect deposit (1) into Vault 1").to.equal(80);
                expect((after.vault1Balance.usdc.sub(before.vault1Balance.dai).toNumber()), "Incorrect deposit (2) into Vault 1").to.equal(50);
                expect((after.vault1Balance.busd.sub(before.vault1Balance.dai).toNumber()), "Incorrect deposit (3) into Vault 1").to.equal(100);
                expect((after.vault2Balance.dai.sub(before.vault1Balance.dai).toNumber()), "Incorrect deposit (1) into Vault 2").to.equal(20);
                expect((after.vault2Balance.usdc.sub(before.vault1Balance.dai).toNumber()), "Incorrect deposit (2) into Vault 2").to.equal(30);
                expect((after.vault3Balance.busd.sub(before.vault1Balance.dai).toNumber()), "Incorrect deposit into Vault 3").to.equal(90);

                expect(onHoldAmount.vault1.dai.toNumber(), "Tokens (1) are not set on-hold in Vault 1").to.equal(80);
                expect(onHoldAmount.vault1.usdc.toNumber(), "Tokens (2) are not set on-hold in Vault 1").to.equal(50);
                expect(onHoldAmount.vault1.busd.toNumber(), "Tokens (3) are not set on-hold in Vault 1").to.equal(100);
                expect(onHoldAmount.vault2.dai.toNumber(), "Tokens (1) are not set on-hold in Vault 2").to.equal(20);
                expect(onHoldAmount.vault2.usdc.toNumber(), "Tokens (2) are not set on-hold in Vault 2").to.equal(30);
                expect(onHoldAmount.vault3.busd.toNumber(), "Tokens are not set on-hold in Vault 3").to.equal(90);

                expect(userPoolBalanceToken1.toNumber(), "Pool tokens (1) are not minted").to.equal(80 + 50 + 100);
                expect(userPoolBalanceToken2.toNumber(), "Pool tokens (2) are not minted").to.equal(20 + 30);
                expect(userPoolBalanceToken3.toNumber(), "Pool tokens (3) are not minted").to.equal(90);
            });

        });

    });

    describe('Withdraw through VaultSavings', () => {
        let vault2: VaultProtocolInstance;
        let vault3: VaultProtocolInstance;
        let poolToken2: VaultPoolTokenInstance;
        let poolToken3: VaultPoolTokenInstance;
        let strategy2: VaultStrategyStubInstance;
        let strategy3: VaultStrategyStubInstance;

        afterEach(async() => await globalSnap.revert());

        beforeEach(async() => {
            vault2 = await VaultProtocol.new({ from: owner });
            await (<VaultProtocolInstance>vault2).methods['initialize(address,address[])'](
                pool.address, [dai.address, usdc.address], { from: owner });
            await vault2.addDefiOperator(vaultSavings.address, { from: owner });
            await vault2.addDefiOperator(defiops, { from: owner });

            await vault2.setAvailableEnabled(true, { from: owner });

            vault3 = await VaultProtocol.new({ from: owner });
            await (<VaultProtocolInstance>vault3).methods['initialize(address,address[])'](
                pool.address, [busd.address], { from: owner });
            await vault3.addDefiOperator(vaultSavings.address, { from: owner });
            await vault3.addDefiOperator(defiops, { from: owner });

            await vault3.setAvailableEnabled(true, { from: owner });

            poolToken2 = await PoolToken.new({ from: owner });
            await (<VaultPoolTokenInstance>poolToken2).methods['initialize(address,string,string)'](
                pool.address, 'VaultSavings', 'VLT', { from: owner });
            await poolToken2.addMinter(vaultSavings.address, { from: owner });
            await poolToken2.addMinter(vaultProtocol.address, { from: owner });
            await poolToken2.addMinter(defiops, { from: owner });

            poolToken3 = await PoolToken.new({ from: owner });
            await (<VaultPoolTokenInstance>poolToken3).methods['initialize(address,string,string)'](
                pool.address, 'VaultSavings', 'VLT', { from: owner });
            await poolToken3.addMinter(vaultSavings.address, { from: owner });
            await poolToken3.addMinter(vaultProtocol.address, { from: owner });
            await poolToken3.addMinter(defiops, { from: owner });

            await vaultSavings.registerVault(vault2.address, poolToken2.address, { from: owner });
            await vaultSavings.registerVault(vault3.address, poolToken3.address, { from: owner });
            await poolToken2.addMinter(vault2.address, { from: owner });
            await poolToken3.addMinter(vault3.address, { from: owner });

            strategy2 = await VaultStrategy.new({ from: owner });
            await (<any> strategy2).methods['initialize(string)']('2', { from: owner });
            await strategy2.setProtocol(protocolStub, { from: owner });    
            await strategy2.addDefiOperator(defiops, { from: owner });
            await strategy2.addDefiOperator(vault2.address, { from: owner });
            await vault2.registerStrategy(strategy2.address, { from: defiops });

            strategy3 = await VaultStrategy.new({ from: owner });
            await (<any> strategy3).methods['initialize(string)']('3', { from: owner });
            await strategy3.setProtocol(protocolStub, { from: owner });    
            await strategy3.addDefiOperator(defiops, { from: owner });
            await strategy3.addDefiOperator(vault3.address, { from: owner });
            await vault3.registerStrategy(strategy3.address, { from: defiops });


            await dai.approve(vaultProtocol.address, 200, { from: user1 });
            await usdc.approve(vaultProtocol.address, 200, { from: user1 });
            await busd.approve(vaultProtocol.address, 200, { from: user1 });
            await dai.approve(vault2.address, 200, { from: user1 });
            await usdc.approve(vault2.address, 200, { from: user1 });
            await busd.approve(vault3.address, 200, { from: user1 });

            await (<any>vaultSavings).methods['depositAll(address[],address[],uint256[])'](
                [vaultProtocol.address, vault2.address, vault3.address],
                [dai.address, usdc.address, busd.address, dai.address, usdc.address, busd.address],
                [80, 50, 100, 20, 30, 90],
                { from: user1 }
            );

            await vaultSavings.methods['handleOperatorActions(address,address)'](vaultProtocol.address, strategy.address, { from: defiops });
            await vaultSavings.methods['handleOperatorActions(address,address)'](vault2.address, strategy2.address, { from: defiops });
            await vaultSavings.methods['handleOperatorActions(address,address)'](vault3.address, strategy3.address, { from: defiops });

        });

        it('User burns LP tokens', async() => {
            //Check that LP tokens are burnt
        });

        it('Withdraw request is created for one token', async() => {
            //Call withdraw for one token
            //Check request in the vault
        });

        it('Withdraw requests are created for several tokens in the Vault', async() => {
            //Call withdraw with several coins from a vault
            //Check request in the vault
        });

        it('Withdraw request are created for several Vaults (many tokens)', async() => {
            //Call withdraw with several coins from several vaults (withdrawAll)

            //Check that LP tokens are burnt
            //Check that each vault gets requests
        });

    });

    describe('Operator resolves deposits through the VaultSavings', () => {

        beforeEach(async() => {
            await dai.approve(vaultProtocol.address, 80, { from: user1 });
            await (<any> vaultSavings).methods['deposit(address,address[],uint256[])'](
                vaultProtocol.address, [dai.address], [80], { from: user1 });

            await dai.approve(vaultProtocol.address, 50, { from: user2 });
            await (<any> vaultSavings).methods['deposit(address,address[],uint256[])'](
                vaultProtocol.address, [dai.address], [50], { from: user2 });
        });

        afterEach(async() => {
            await globalSnap.revert();
        });

        it('LP tokens are unmarked from being on-hold after deposit is resolved by operator', async() => {
            await vaultSavings.methods['handleOperatorActions(address,address)'](vaultProtocol.address, strategy.address, { from: defiops });
            await vaultSavings.clearProtocolStorage(vaultProtocol.address, { from: defiops });


            let onHoldPool = await poolToken.onHoldBalanceOf(user1, { from: owner });
            expect(onHoldPool.toNumber(), 'Pool tokens are not earning yield for user (1)').to.equal(0);
            onHoldPool = await poolToken.onHoldBalanceOf(user2, { from: owner });
            expect(onHoldPool.toNumber(), 'Pool tokens are not earning yield for user (2)').to.equal(0);
        });

        it('First deposit (no yield earned yet)', async() => {
            const before = {
                userBalance1: await dai.balanceOf(user1, { from: user1 }),
                userBalance2: await dai.balanceOf(user2, { from: user2 }),
                poolBalance1: await poolToken.balanceOf(user1, { from: user1 }),
                poolBalance2: await poolToken.balanceOf(user2, { from: user2 })
            };

            await vaultSavings.methods['handleOperatorActions(address,address)'](vaultProtocol.address, strategy.address, { from: defiops });
            await vaultSavings.clearProtocolStorage(vaultProtocol.address, { from: defiops });

            const vaultBalance = await dai.balanceOf(vaultProtocol.address, { from: owner });
            expect(vaultBalance.toNumber(), 'Tokens are not deposited from vault').to.equal(0);

            const protocolBalance = await dai.balanceOf(protocolStub, { from: owner });
            expect(protocolBalance.toNumber(), 'Tokens are not deposited').to.equal(130);

            let userOnHold = await vaultProtocol.amountOnHold(user1, dai.address, { from: owner });
            expect(userOnHold.toNumber(), 'On-hold record for (1) was not deleted').to.equal(0);

            userOnHold = await vaultProtocol.amountOnHold(user2, dai.address, { from: owner });
            expect(userOnHold.toNumber(), 'On-hold record for (2) was not deleted').to.equal(0);

            const poolBalance = await poolToken.balanceOf(poolToken.address, { from: owner });
            expect(poolBalance.toNumber(), 'No new pool tokens minted').to.equal(0);

            const after = {
                userBalance1: await dai.balanceOf(user1, { from: user1 }),
                userBalance2: await dai.balanceOf(user2, { from: user2 }),
                poolBalance1: await poolToken.balanceOf(user1, { from: user1 }),
                poolBalance2: await poolToken.balanceOf(user2, { from: user2 })
            };

            expect(before.userBalance1.sub(after.userBalance1).toNumber(), 'User (1) should not receive any tokens')
                .to.equal(0);
            expect(before.userBalance2.sub(after.userBalance2).toNumber(), 'User (2) should not receive any tokens')
                .to.equal(0);
            expect(before.poolBalance1.sub(after.poolBalance1).toNumber(),
                'User (1) should not receive new pool tokens').to.equal(0);
            expect(before.poolBalance2.sub(after.poolBalance2).toNumber(),
                'User (2) should not receive new pool tokens').to.equal(0);
        });

        it('First deposit (no yield available)', async() => {
            const before = {
                yieldBalance1: await poolToken.calculateUnclaimedDistributions(user1, { from: user1 }),
                yieldBalance2: await poolToken.calculateUnclaimedDistributions(user2, { from: user2 })
            };

            await vaultSavings.methods['handleOperatorActions(address,address)'](vaultProtocol.address, strategy.address, { from: defiops });
            await vaultSavings.clearProtocolStorage(vaultProtocol.address, { from: defiops });

            const after = {
                yieldBalance1: await poolToken.calculateUnclaimedDistributions(user1, { from: user1 }),
                yieldBalance2: await poolToken.calculateUnclaimedDistributions(user2, { from: user2 })
            };

            expect(before.yieldBalance1.sub(after.yieldBalance1).toNumber(), 'No yield for user (1) yet').to.equal(0);
            expect(before.yieldBalance2.sub(after.yieldBalance2).toNumber(), 'No yield for user (2) yet').to.equal(0);
        });


        it('Deposit with some users earned yield', async() => {
            // TODO
        });
    });

    describe('Single token action', () => {
        beforeEach(async() => {
            await dai.approve(vaultProtocol.address, 100, { from: user1 });
            await usdc.approve(vaultProtocol.address, 100, { from: user1 });
            await busd.approve(vaultProtocol.address, 100, { from: user1 });
        });

        afterEach(async() => {
            await globalSnap.revert();
        });
        it('Operator resolves deposit for the single token', async() => {
            //Deposit from user1 in 3 different tokens
            //Operator action for 1 token (dai)
            //Check that 1 token moved to the strategy and other tokens are untouched
            //Additional deposit fro user1 in 1 token (dai)
            //Operator action for 1 token (dai)
            //Check that 1 token moved to the strategy and other tokens are untouched
        });

        it('Operator resolves withdraw request for the single token', async() => {
            //Deposit from user1 in 3 different tokens
            //Operator action for all tokens
            //Withdraw of half of the sum from user1 in 1 token (dai)
            //Check that withdraw request was created
            //Operator action for 1 token (dai)
            //Check that user1 can claim requested token and other 2 are untouched
            //Additional withdraw request (for the second half) from user1 in 1 token (dai)
            //Operator action for 1 token (dai)
            //Check that user1 can claim requested token (full amount) and other 2 are untouched
        });
    });

    describe('Yield distribution', () => {

        beforeEach(async() => {
            await dai.approve(vaultProtocol.address, 80, { from: user1 });
            await (<any> vaultSavings).methods['deposit(address,address[],uint256[])'](
                vaultProtocol.address, [dai.address], [80], { from: user1 });

            await dai.approve(vaultProtocol.address, 50, { from: user2 });
            await (<any> vaultSavings).methods['deposit(address,address[],uint256[])'](
                vaultProtocol.address, [dai.address], [50], { from: user2 });
        });

        afterEach(async() => {
            await globalSnap.revert();
        });

        //The user gets yeild only if he has no on-hold deposits

        it('Yield is distributed for the user after new tokens minted', async() => {
            await vaultSavings.methods['handleOperatorActions(address,address)'](vaultProtocol.address, strategy.address, { from: defiops });
            await vaultSavings.clearProtocolStorage(vaultProtocol.address, { from: defiops });

            //Add yield to the protocol
            await dai.transfer(protocolStub, 26, { from: owner });

            await (<any> vaultSavings).methods['distributeYield(address)'](vaultProtocol.address, { from: defiops });

            //16 new LP tokens for 80/130
            let unclaimedTokens = await poolToken.calculateUnclaimedDistributions(user1, { from: owner });
            expect(unclaimedTokens.toNumber(), 'No yield for user (1) yet').to.equal(16);

            //additional deposit
            await dai.approve(vaultProtocol.address, 20, { from: user1 });
            await (<any> vaultSavings).methods['deposit(address,address[],uint256[])'](
                vaultProtocol.address, [dai.address], [20], { from: user1 });

            //Yield distributed
            unclaimedTokens = await poolToken.calculateUnclaimedDistributions(user1, { from: owner });
            expect(unclaimedTokens.toNumber(), 'No additional yield for user (1) should be distributed').to.equal(0);

            //80 LP + 16 LP yield + 20 on-hold LP
            const poolBalance = await poolToken.balanceOf(user1);
            expect(poolBalance.toNumber(), 'Incorrect number of tokens minted').to.equal(116);

            //On-hold tokens do not participate in distribution
            const distrBalance = await poolToken.distributionBalanceOf(user1, { from: owner });
            expect(distrBalance.toNumber(), 'Ob-hold tokens should not participate in distribution').to.equal(96);
        });

        it('Additional deposit does not influence yield while being on-hold', async() => {
            await vaultSavings.methods['handleOperatorActions(address,address)'](vaultProtocol.address, strategy.address, { from: defiops });
            await vaultSavings.clearProtocolStorage(vaultProtocol.address, { from: defiops });

            //additional deposit
            await dai.approve(vaultProtocol.address, 20, { from: user1 });
            await (<any> vaultSavings).methods['deposit(address,address[],uint256[])'](
                vaultProtocol.address, [dai.address], [20], { from: user1 });

            //Add yield to the protocol
            await dai.transfer(protocolStub, 26, { from: owner });

            await (<any> vaultSavings).methods['distributeYield(address)'](vaultProtocol.address, { from: defiops });

            //16 new LP tokens for 80/130
            const unclaimedTokens = await poolToken.calculateUnclaimedDistributions(user1, { from: owner });
            expect(unclaimedTokens.toNumber(), 'No yield for user (1) yet').to.equal(16);

            //additional deposit will not participate in distribution
            const distrBalance = await poolToken.distributionBalanceOf(user1, { from: owner });
            expect(distrBalance.toNumber(), 'On-hold tokens should not participate in distribution').to.equal(80);
        });

        it('New deposit does not participate in distribution', async() => {
            await vaultSavings.methods['handleOperatorActions(address,address)'](vaultProtocol.address, strategy.address, { from: defiops });
            await vaultSavings.clearProtocolStorage(vaultProtocol.address, { from: defiops });

            //additional deposit - 80 in protocol and 20 on-hold
            await dai.approve(vaultProtocol.address, 20, { from: user1 });
            await (<any> vaultSavings).methods['deposit(address,address[],uint256[])'](
                vaultProtocol.address, [dai.address], [20], { from: user1 });

            //Add yield to the protocol
            await dai.transfer(protocolStub, 26, { from: owner });

            //move additional deposit into the protocol
            await vaultSavings.methods['handleOperatorActions(address,address)'](vaultProtocol.address, strategy.address, { from: defiops });
            await vaultSavings.clearProtocolStorage(vaultProtocol.address, { from: defiops });

            //User1 has received his yield - because his shared part has changed
            //80 (working) + 20 (new) + 16 (yield)
            const user1PoolBalance = await poolToken.balanceOf(user1, { from: user1 });
            expect(user1PoolBalance.toNumber(), 'Incorrect amount of pool tokens').to.equal(116);

            //User1 has received his yield after distribution created by operator
            const poolBalance = await poolToken.balanceOf(poolToken.address, { from: owner });
            expect(poolBalance.toNumber(), 'Incorrect amount of yield left').to.equal(10);


            //User1 has already received his yield (by old amount)
            let unclaimedTokens = await poolToken.calculateUnclaimedDistributions(user1, { from: owner });
            expect(unclaimedTokens.toNumber(), 'No yield for user (1) should be left').to.equal(0);

            //Unchanged yield for user2
            unclaimedTokens = await poolToken.calculateUnclaimedDistributions(user2, { from: owner });
            expect(unclaimedTokens.toNumber(), 'No yield for user (2)').to.equal(10);
        });

    });

    describe('Full cycle', () => {

        beforeEach(async() => dai.approve(strategy.address, 10000, { from: protocolStub }));

        afterEach(async() => await globalSnap.revert());

        it('Full cycle of deposit->yield->withdraw', async() => {
            // Preliminary
            // Deposit from user1
            await dai.approve(vaultProtocol.address, 80, { from: user1 });
            await (<VaultSavingsModuleInstance> vaultSavings).methods['deposit(address,address[],uint256[])'](
                vaultProtocol.address, [dai.address], [80], { from: user1 });

            // Deposit from user2
            await dai.approve(vaultProtocol.address, 50, { from: user2 });
            await (<VaultSavingsModuleInstance> vaultSavings).methods['deposit(address,address[],uint256[])'](
                vaultProtocol.address, [dai.address], [50], { from: user2 });

            // Operator resolves deposits
            await vaultSavings.methods['handleOperatorActions(address,address)'](vaultProtocol.address, strategy.address, { from: defiops });
            await vaultSavings.clearProtocolStorage(vaultProtocol.address, { from: defiops });

            // no yield yet - user balances are unchanged
            let user1PoolBalance = await poolToken.balanceOf(user1, { from: user1 });
            expect(user1PoolBalance.toNumber(), 'No new pool tokens should be minted for user1').to.equal(80);

            let user2PoolBalance = await poolToken.balanceOf(user2, { from: user2 });
            expect(user2PoolBalance.toNumber(), 'No new pool tokens should be  minted for user2').to.equal(50);

            let poolBalance = await poolToken.balanceOf(poolToken.address, { from: owner });
            expect(poolBalance.toNumber(), 'No new pool tokens minted').to.equal(0);

            let unclaimedTokens = await poolToken.calculateUnclaimedDistributions(user1, { from: owner });
            expect(unclaimedTokens.toNumber(), 'No yield for user (1) yet').to.equal(0);

            unclaimedTokens = await poolToken.calculateUnclaimedDistributions(user2, { from: owner });
            expect(unclaimedTokens.toNumber(), 'No yield for user (2) yet').to.equal(0);

            // First case
            // Add yield to the protocol
            await dai.transfer(protocolStub, 26, { from: owner });

            //Deposit from User3
            await dai.approve(vaultProtocol.address, 20, { from: user3 });
            await (<VaultSavingsModuleInstance> vaultSavings).methods['deposit(address,address[],uint256[])'](
                vaultProtocol.address, [dai.address], [20], { from: user3 });

            let user3PoolBalance = await poolToken.balanceOf(user3, { from: user3 });
            expect(user3PoolBalance.toNumber(), 'Pool tokens are not minted for user3').to.equal(20);

            //Operator resolves deposits
            await vaultSavings.methods['handleOperatorActions(address,address)'](vaultProtocol.address, strategy.address, { from: defiops });
            await vaultSavings.clearProtocolStorage(vaultProtocol.address, { from: defiops });
            //Yield from pool is distributed before the new deposit (on-hold deposit is not counted)
            //26 tokens of yield for deposits 80 + 50 = 130, 16 + 10 tokens of yield

            poolBalance = await poolToken.balanceOf(poolToken.address, { from: owner });
            expect(poolBalance.toNumber(), 'Yield tokens are not minted').to.equal(26);

            //Yield is not claimed yet
            user1PoolBalance = await poolToken.balanceOf(user1, { from: user1 });
            expect(user1PoolBalance.toNumber(), 'Yield tokens should not be claimed yet for user1').to.equal(80);

            user2PoolBalance = await poolToken.balanceOf(user2, { from: user2 });
            expect(user2PoolBalance.toNumber(), 'Yield tokens should not be claimed yet for user2').to.equal(50);

            user3PoolBalance = await poolToken.balanceOf(user3, { from: user3 });
            expect(user3PoolBalance.toNumber(), 'Yield tokens should not be claimed yet for user3').to.equal(20);

            //Yield ready fo claim
            unclaimedTokens = await poolToken.calculateUnclaimedDistributions(user1, { from: owner });
            expect(unclaimedTokens.toNumber(), 'Yield was not distributed for user1').to.equal(16);

            unclaimedTokens = await poolToken.calculateUnclaimedDistributions(user2, { from: owner });
            expect(unclaimedTokens.toNumber(), 'Yield was not distributed for user2').to.equal(10);

            unclaimedTokens = await poolToken.calculateUnclaimedDistributions(user3, { from: owner });
            expect(unclaimedTokens.toNumber(), 'Yield should not be distributed for user1').to.equal(0);

            //Additional deposit from user1
            await dai.approve(vaultProtocol.address, 20, { from: user1 });
            await (<VaultSavingsModuleInstance> vaultSavings).methods['deposit(address,address[],uint256[])'](
                vaultProtocol.address, [dai.address], [20], { from: user1 });

            //Since new tokens are minted, user1 gets distribution
            unclaimedTokens = await poolToken.calculateUnclaimedDistributions(user1, { from: owner });
            expect(unclaimedTokens.toNumber(), 'Yield was transfered to user1').to.equal(0);

            user1PoolBalance = await poolToken.balanceOf(user1, { from: user1 });
            //80 first deposit + 20 on-hold + 16 yield LP
            expect(user1PoolBalance.toNumber(), 'No new pool tokens minted for user1').to.equal(116);


            //User2 claims yield
            await poolToken.methods['claimDistributions(address)'](user2, { from: user2 });

            unclaimedTokens = await poolToken.calculateUnclaimedDistributions(user2, { from: owner });
            expect(unclaimedTokens.toNumber(), 'Yield was not claimed by user2').to.equal(0);

            user2PoolBalance = await poolToken.balanceOf(user2, { from: user2 });
            //50 LP tokens + 10 LP yield
            expect(user2PoolBalance.toNumber(), 'No new pool tokens minted for user2').to.equal(60);

            //Second case
            //Make sure, that all LP tokens are working
            await vaultSavings.methods['handleOperatorActions(address,address)'](vaultProtocol.address, strategy.address, { from: defiops });
            await vaultSavings.clearProtocolStorage(vaultProtocol.address, { from: defiops });

            //Withdraw by user 2
            await vaultSavings.methods['withdraw(address,address,uint256)'](vaultProtocol.address, dai.address, 60, { from: user2 });

            //LP tokens from user2 are burned
            user2PoolBalance = await poolToken.balanceOf(user2, { from: user2 });
            expect(user2PoolBalance.toNumber(), 'LP tokens were not burned for user2').to.equal(0);

            //Withdraw request is created
            const requestedAmount = await vaultProtocol.amountRequested(user2, dai.address);
            expect(requestedAmount.toNumber(), 'Request should be created').to.equal(60);

            //Add yield to the protocol
            //For ease of calculations: 34 = 29 + 5 -> in proportion for 116/136 (user1) and 20/136 (user3)
            await dai.transfer(protocolStub, 34, { from: owner });

            //Request handling

            //Imitate distribution period
            await blockTimeTravel(await vaultSavings.DISTRIBUTION_AGGREGATION_PERIOD());

            await vaultSavings.methods['handleOperatorActions(address,address)'](vaultProtocol.address, strategy.address, { from: defiops });
            await vaultSavings.clearProtocolStorage(vaultProtocol.address, { from: defiops });

            //User2 can claim his requested tokens
            const claimableTokens = await vaultProtocol.claimableAmount(user2, dai.address);
            expect(claimableTokens.toNumber(), 'No tokens can be claimed by user2').to.equal(60);

            let balanceBefore = await dai.balanceOf(user2);
            await vaultSavings.claimAllRequested(vaultProtocol.address, { from: user2 });
            let balanceAfter = await dai.balanceOf(user2);

            expect(balanceAfter.sub(balanceBefore).toNumber(), 'Requested tokens are not claimed by user2')
                .to.equal(60);

            //Yield distribution (user2 is without LP tokens - only 1 and 3 receive yield)
            //User1: 116 LP + 29 LP yield
            unclaimedTokens = await poolToken.calculateUnclaimedDistributions(user1, { from: owner });
            expect(unclaimedTokens.toNumber(), 'Yield was not distributed for user1 (second case)').to.equal(29);

            user1PoolBalance = await poolToken.balanceOf(user1, { from: user1 });
            expect(user1PoolBalance.toNumber(), 'No new pool tokens should be minted for user1 (second case)')
                .to.equal(116);

            //User2: 0 LP + 0 LP yield
            unclaimedTokens = await poolToken.calculateUnclaimedDistributions(user2, { from: owner });
            expect(unclaimedTokens.toNumber(), 'Yield should not be distributed for user2 (second case)').to.equal(0);

            user2PoolBalance = await poolToken.balanceOf(user2, { from: user2 });
            expect(user2PoolBalance.toNumber(), 'No new pool tokens should be minted for user1 (second case)')
                .to.equal(0);

            //User3: 20 LP + 5 LP yield
            unclaimedTokens = await poolToken.calculateUnclaimedDistributions(user3, { from: owner });
            expect(unclaimedTokens.toNumber(), 'Yield was not distributed for user1 (second case)').to.equal(5);

            user3PoolBalance = await poolToken.balanceOf(user3, { from: user3 });
            expect(user3PoolBalance.toNumber(), 'No new pool tokens should be minted for user1 (second case)')
                .to.equal(20);

            //Users claim yield
            await poolToken.methods['claimDistributions(address)'](user1, { from: user1 });
            await poolToken.methods['claimDistributions(address)'](user3, { from: user3 });

            //All LP tokens are claimed
            //116 LP + 29 LP yield
            user1PoolBalance = await poolToken.balanceOf(user1, { from: user1 });
            expect(user1PoolBalance.toNumber(), 'Incorrect LP balance for user1 (second case)').to.equal(145);

            //20 LP + 5 LP yield
            user3PoolBalance = await poolToken.balanceOf(user3, { from: user3 });
            expect(user3PoolBalance.toNumber(), 'Incorrect LP balance for user3 (second case)').to.equal(25);

            //Third case
            //User1 requests particular withdraw - LP tokens are sent to the protocol and burned
            await vaultSavings.methods['withdraw(address,address,uint256)'](vaultProtocol.address, dai.address, 45, { from: user1 });

            user1PoolBalance = await poolToken.balanceOf(user1, { from: user1 });
            expect(user1PoolBalance.toNumber(), 'User1 hasn\'t sent LP tokens to the protocol (third case)')
                .to.equal(100);

            poolBalance = await poolToken.balanceOf(vaultSavings.address, { from: owner });
            expect(poolBalance.toNumber(), 'Should be no pool tokens in VaultSavings').to.equal(0);
            poolBalance = await poolToken.balanceOf(poolToken.address, { from: owner });
            expect(poolBalance.toNumber(), 'Pool tokens are not burned').to.equal(0);


            //Add yield to the protocol
            //100 LP + 25 LP -> 4:1 -> 25 LP tokens yield -> 20 LP + 5 LP
            await dai.transfer(protocolStub, 25, { from: owner });

            //Distribute yield
            await blockTimeTravel(await vaultSavings.DISTRIBUTION_AGGREGATION_PERIOD());
            await (<VaultSavingsModuleInstance> vaultSavings).distributeYield(vaultProtocol.address, { from: defiops });

            //Yield from pool is distributed before the request resolving
            //user1 and user3 can claim yield according to their LP tokens amounts

            //user1 gets the amount according to available LP tokens (100)
            //user1: 100 LP + 20 LP yield
            unclaimedTokens = await poolToken.calculateUnclaimedDistributions(user1, { from: owner });
            expect(unclaimedTokens.toNumber(), 'Yield was not distributed for user1 (third case)').to.equal(20);

            user1PoolBalance = await poolToken.balanceOf(user1, { from: user1 });
            expect(user1PoolBalance.toNumber(), 'No new pool tokens should be minted for user1 (third case)')
                .to.equal(100);

            //User3: 25 LP + 5 LP yield
            unclaimedTokens = await poolToken.calculateUnclaimedDistributions(user3, { from: owner });
            expect(unclaimedTokens.toNumber(), 'Yield was not distributed for user3 (third case)').to.equal(5);

            user3PoolBalance = await poolToken.balanceOf(user3, { from: user3 });
            expect(user3PoolBalance.toNumber(), 'No new pool tokens should be minted for user3 (third case)')
                .to.equal(25);

            //Operator resolves withdraw requests
            await vaultSavings.methods['handleOperatorActions(address,address)'](vaultProtocol.address, strategy.address, { from: defiops });
            await vaultSavings.clearProtocolStorage(vaultProtocol.address, { from: defiops });

            //Unclaimed amounts are not changed
            unclaimedTokens = await poolToken.calculateUnclaimedDistributions(user1, { from: owner });
            expect(unclaimedTokens.toNumber(), 'Yield was changed for user1 (third case)').to.equal(20);

            unclaimedTokens = await poolToken.calculateUnclaimedDistributions(user3, { from: owner });
            expect(unclaimedTokens.toNumber(), 'Yield was changed for user3 (third case)').to.equal(5);

            //User1 claimes requested coins
            balanceBefore = await dai.balanceOf(user1);
            await vaultSavings.claimAllRequested(vaultProtocol.address, { from: user1 });
            balanceAfter = await dai.balanceOf(user1);

            expect(balanceAfter.sub(balanceBefore).toNumber(), 'Requested tokens are not claimed by user1')
                .to.equal(45);
        });

    });

});
