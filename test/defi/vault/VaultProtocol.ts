import {
    VaultProtocolContract, VaultProtocolInstance,
    VaultPoolTokenContract, VaultPoolTokenInstance,
    PoolContract, PoolInstance,
    TestErc20Contract, TestErc20Instance,
    VaultSavingsModuleContract, VaultSavingsModuleInstance,
    VaultStrategyStubContract, VaultStrategyStubInstance, AccessModuleInstance
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
const VaultProtocol = artifacts.require('VaultProtocol');
const VaultStrategy = artifacts.require('VaultStrategyStub');
const PoolToken = artifacts.require('VaultPoolToken');
const AccessModule = artifacts.require('AccessModule');

contract('VaultProtocol', async([ _, owner, user1, user2, user3, defiops, protocolStub, ...otherAccounts ]) => {

    let globalSnap: Snapshot;
    let vaultProtocol: VaultProtocolInstance;
    let dai: TestErc20Instance;
    let usdc: TestErc20Instance;
    let busd: TestErc20Instance;
    let usdt: TestErc20Instance;
    let poolToken: VaultPoolTokenInstance;
    let pool: PoolInstance;
    let vaultSavings: VaultSavingsModuleInstance;
    let strategy: VaultStrategyStubInstance;
    let accessModule: AccessModuleInstance;

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
        //Deposit token 4
        usdt = await ERC20.new({ from: owner });
        await (<any> usdt).methods['initialize(string,string,uint8)']('USDT', 'USDT', 18, { from: owner });

        await dai.transfer(user1, 1000, { from: owner });
        await dai.transfer(user2, 1000, { from: owner });
        await dai.transfer(user3, 1000, { from: owner });

        await usdc.transfer(user1, 1000, { from: owner });
        await usdc.transfer(user2, 1000, { from: owner });
        await usdc.transfer(user3, 1000, { from: owner });

        await busd.transfer(user1, 1000, { from: owner });
        await busd.transfer(user2, 1000, { from: owner });
        await busd.transfer(user3, 1000, { from: owner });

        await usdt.transfer(user1, 1000, { from: owner });
        await usdt.transfer(user2, 1000, { from: owner });
        await usdt.transfer(user3, 1000, { from: owner });
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
            pool.address, [dai.address, usdc.address, busd.address, usdt.address], { from: owner });
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
        await vaultProtocol.setQuickWithdrawStrategy(strategy.address, { from: defiops });
        await vaultProtocol.setAvailableEnabled(true, { from: owner });
        //------
        await vaultSavings.registerVault(vaultProtocol.address, poolToken.address, { from: owner });

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

        it('Deposit several tokens into the vault (one-by-one)', async() => {
            const before = {
                vaultBalance1: await dai.balanceOf(vaultProtocol.address),
                vaultBalance2: await usdc.balanceOf(vaultProtocol.address),
                vaultBalance3: await busd.balanceOf(vaultProtocol.address)
            };

            await dai.transfer(vaultProtocol.address, 10, { from: user1 });
            await (<any> vaultProtocol)
                .methods['depositToVault(address,address,uint256)'](user1, dai.address, 10, { from: defiops });
            await usdc.transfer(vaultProtocol.address, 20, { from: user1 });
            await (<any> vaultProtocol)
                .methods['depositToVault(address,address,uint256)'](user1, usdc.address, 20, { from: defiops });
            await busd.transfer(vaultProtocol.address, 30, { from: user1 });
            await (<any> vaultProtocol)
                .methods['depositToVault(address,address,uint256)'](user1, busd.address, 30, { from: defiops });

            let onhold = await vaultProtocol.amountOnHold(user1, dai.address);
            expect(onhold.toNumber(), 'Deposit (1) was not added to on-hold').to.equal(10);

            onhold = await vaultProtocol.amountOnHold(user1, usdc.address);
            expect(onhold.toNumber(), 'Deposit (2) was not added to on-hold').to.equal(20);

            onhold = await vaultProtocol.amountOnHold(user1, busd.address);
            expect(onhold.toNumber(), 'Deposit (3) was not added to on-hold').to.equal(30);

            const after = {
                vaultBalance1: await dai.balanceOf(vaultProtocol.address),
                vaultBalance2: await usdc.balanceOf(vaultProtocol.address),
                vaultBalance3: await busd.balanceOf(vaultProtocol.address)
            };
            expect(after.vaultBalance1.sub(before.vaultBalance1).toNumber(), 'Tokens (1) are not transferred to vault')
                .to.equal(10);
            expect(after.vaultBalance2.sub(before.vaultBalance2).toNumber(), 'Tokens (2) are not transferred to vault')
                .to.equal(20);
            expect(after.vaultBalance3.sub(before.vaultBalance3).toNumber(), 'Tokens (3) are not transferred to vault')
                .to.equal(30);
        });

        it('Deposit several tokens into the vault', async() => {
            const before = {
                vaultBalance1: await dai.balanceOf(vaultProtocol.address),
                vaultBalance2: await usdc.balanceOf(vaultProtocol.address),
                vaultBalance3: await busd.balanceOf(vaultProtocol.address)
            };

            await dai.transfer(vaultProtocol.address, 10, { from: user1 });
            await usdc.transfer(vaultProtocol.address, 20, { from: user1 });
            await busd.transfer(vaultProtocol.address, 30, { from: user1 });

            await (<any> vaultProtocol).methods['depositToVault(address,address[],uint256[])'](
                user1, [dai.address, usdc.address, busd.address], [10, 20, 30],
                { from: defiops });

            let onhold = await vaultProtocol.amountOnHold(user1, dai.address);
            expect(onhold.toNumber(), 'Deposit (1) was not added to on-hold').to.equal(10);

            onhold = await vaultProtocol.amountOnHold(user1, usdc.address);
            expect(onhold.toNumber(), 'Deposit (2) was not added to on-hold').to.equal(20);

            onhold = await vaultProtocol.amountOnHold(user1, busd.address);
            expect(onhold.toNumber(), 'Deposit (3) was not added to on-hold').to.equal(30);

            const after = {
                vaultBalance1: await dai.balanceOf(vaultProtocol.address),
                vaultBalance2: await usdc.balanceOf(vaultProtocol.address),
                vaultBalance3: await busd.balanceOf(vaultProtocol.address)
            };
            expect(after.vaultBalance1.sub(before.vaultBalance1).toNumber(), 'Tokens (1) are not transferred to vault')
                .to.equal(10);
            expect(after.vaultBalance2.sub(before.vaultBalance2).toNumber(), 'Tokens (2) are not transferred to vault')
                .to.equal(20);
            expect(after.vaultBalance3.sub(before.vaultBalance3).toNumber(), 'Tokens (3) are not transferred to vault')
                .to.equal(30);
        });

        it('Deposit from several users to the vault', async() => {
            const before = {
                vaultBalance: await dai.balanceOf(vaultProtocol.address)
            };

            await dai.transfer(vaultProtocol.address, 10, { from: user1 });
            await (<any> vaultProtocol).methods['depositToVault(address,address,uint256)'](
                user1, dai.address, 10, { from: defiops });
            await dai.transfer(vaultProtocol.address, 20, { from: user2 });
            await (<any> vaultProtocol).methods['depositToVault(address,address,uint256)'](
                user2, dai.address, 20, { from: defiops });

            let onhold = await vaultProtocol.amountOnHold(user1, dai.address);
            expect(onhold.toNumber(), 'Deposit (1) was not added to on-hold').to.equal(10);

            onhold = await vaultProtocol.amountOnHold(user2, dai.address);
            expect(onhold.toNumber(), 'Deposit (2) was not added to on-hold').to.equal(20);

            const after = {
                vaultBalance: await dai.balanceOf(vaultProtocol.address)
            };
            expect(after.vaultBalance.sub(before.vaultBalance).toNumber(), 'Tokens are not transferred to vault')
                .to.equal(30);
        });

        it('Additional deposit', async() => {
            const before = {
                userBalance: await dai.balanceOf(user1),
                vaultBalance: await dai.balanceOf(vaultProtocol.address)
            };

            await dai.transfer(vaultProtocol.address, 30, { from: user1 });
            await (<any> vaultProtocol).methods['depositToVault(address,address,uint256)'](
                user1, dai.address, 10, { from: defiops });
            const depositResult = await (<any> vaultProtocol).methods['depositToVault(address,address,uint256)'](
                user1, dai.address, 20, { from: defiops });

            expectEvent(depositResult, 'DepositToVault', { _user: user1, _token: dai.address, _amount: '20' });

            const onhold = await vaultProtocol.amountOnHold(user1, dai.address);
            expect(onhold.toNumber(), 'Deposit was not added to on-hold').to.equal(30);

            const after = {
                userBalance: await dai.balanceOf(user1),
                vaultBalance: await dai.balanceOf(vaultProtocol.address)
            };
            expect(after.vaultBalance.sub(before.vaultBalance).toNumber(), 'Tokens are not transferred to vault')
                .to.equal(30);
            expect(before.userBalance.sub(after.userBalance).toNumber(), 'Tokens are not transferred from user')
                .to.equal(30);
        });
    });

    describe('Withdraw token if on-hold tokens exist', () => {

        let snap: Snapshot;

        before(async() => {
            await dai.transfer(vaultProtocol.address, 100, { from: owner });
            await usdc.transfer(vaultProtocol.address, 100, { from: owner });
            await busd.transfer(vaultProtocol.address, 100, { from: owner });

            await dai.transfer(vaultProtocol.address, 100, { from: user1 });
            await usdc.transfer(vaultProtocol.address, 100, { from: user1 });
            await busd.transfer(vaultProtocol.address, 100, { from: user1 });
            await (<any> vaultProtocol).methods['depositToVault(address,address[],uint256[])'](
                user1, [dai.address, usdc.address, busd.address], [100, 100, 100],
                { from: defiops });

            snap = await Snapshot.create(web3.currentProvider);
        });

        after(async() => await globalSnap.revert());

        afterEach(async() => {
            await snap.revert();
        });

        it('Withdraw tokens from vault (enough liquidity)', async() => {
            const before = {
                userBalance: await dai.balanceOf(user1),
                vaultBalance: await dai.balanceOf(vaultProtocol.address)
            };

            const withdrawResult = await (<any> vaultProtocol)
                .methods['withdrawFromVault(address,address,uint256)'](user1, dai.address, 100, { from: defiops });

            expectEvent(withdrawResult, 'WithdrawFromVault', { _user: user1, _token: dai.address, _amount: '100' });
            expectEvent.notEmitted(withdrawResult, 'WithdrawRequestCreated');

            //Deposit record is removed from on-hold storage
            const onhold = await vaultProtocol.amountOnHold(user1, dai.address);
            expect(onhold.toNumber(), 'On-hold deposit was not withdrawn').to.equal(0);

            const after = {
                userBalance: await dai.balanceOf(user1),
                vaultBalance: await dai.balanceOf(vaultProtocol.address)
            };

            //Token is transfered back to the user
            expect(before.vaultBalance.sub(after.vaultBalance).toNumber(), 'Tokens are not transferred from vault')
                .to.equal(100);
            expect(after.userBalance.sub(before.userBalance).toNumber(), 'Tokens are not transferred to user')
                .to.equal(100);
        });

        it('Withdraw more tokens than deposited on-hold (enough liquidity)', async() => {
            const before = {
                userBalance: await dai.balanceOf(user1),
                vaultBalance: await dai.balanceOf(vaultProtocol.address)
            };

            const withdrawResult = await (<any> vaultProtocol)
                .methods['withdrawFromVault(address,address,uint256)'](user1, dai.address, 150, { from: defiops });

            expectEvent(withdrawResult, 'WithdrawFromVault', { _user: user1, _token: dai.address, _amount: '150' });
            expectEvent.notEmitted(withdrawResult, 'WithdrawRequestCreated');

            //Deposit record is removed from on-hold storage
            const onholdAfter = await vaultProtocol.amountOnHold(user1, dai.address);
            expect(onholdAfter.toNumber(), 'On-hold deposit was not withdrawn').to.equal(0);

            const after = {
                userBalance: await dai.balanceOf(user1),
                vaultBalance: await dai.balanceOf(vaultProtocol.address)
            };

            //Token is transfered back to the user
            expect(before.vaultBalance.sub(after.vaultBalance).toNumber(), 'Tokens are not transferred from vault')
                .to.equal(150);
            expect(after.userBalance.sub(before.userBalance).toNumber(), 'Tokens are not transferred to user')
                .to.equal(150);
        });

        it('Withdraw the part of on-hold tokens (enough liquidity)', async() => {
            const before = {
                userBalance: await dai.balanceOf(user1),
                vaultBalance: await dai.balanceOf(vaultProtocol.address)
            };

            const onholdBefore = await vaultProtocol.amountOnHold(user1, dai.address);
            const withdrawResult = await (<any> vaultProtocol)
                .methods['withdrawFromVault(address,address,uint256)'](user1, dai.address, 50, { from: defiops });

            expectEvent(withdrawResult, 'WithdrawFromVault', { _user: user1, _token: dai.address, _amount: '50' });
            expectEvent.notEmitted(withdrawResult, 'WithdrawRequestCreated');

            //Deposit record is updated in the on-hold storage
            const onholdAfter = await vaultProtocol.amountOnHold(user1, dai.address);
            expect(onholdBefore.sub(onholdAfter).toNumber(), 'On-hold deposit was not withdrawn').to.equal(50);

            const after = {
                userBalance: await dai.balanceOf(user1),
                vaultBalance: await dai.balanceOf(vaultProtocol.address)
            };

            //Token is transfered back to the user
            expect(before.vaultBalance.sub(after.vaultBalance).toNumber(), 'Tokens are not transferred from vault')
                .to.equal(50);
            expect(after.userBalance.sub(before.userBalance).toNumber(), 'Tokens are not transferred to user')
                .to.equal(50);
        });

        it('Withdraw if no on-hold tokens (enough liquidity)', async() => {
            const before = {
                userBalance: await dai.balanceOf(user2),
                vaultBalance: await dai.balanceOf(vaultProtocol.address)
            };

            const withdrawResult = await (<any> vaultProtocol)
                .methods['withdrawFromVault(address,address,uint256)'](user2, dai.address, 100, { from: defiops });

            expectEvent(withdrawResult, 'WithdrawFromVault', { _user: user2, _token: dai.address, _amount: '100' });
            expectEvent.notEmitted(withdrawResult, 'WithdrawRequestCreated');

            const onhold = await vaultProtocol.amountOnHold(user2, dai.address);
            expect(onhold.toNumber(), 'On-hold deposit was not withdrawn').to.equal(0);

            const after = {
                userBalance: await dai.balanceOf(user2),
                vaultBalance: await dai.balanceOf(vaultProtocol.address)
            };

            //Token is transfered to the user
            expect(before.vaultBalance.sub(after.vaultBalance).toNumber(), 'Tokens are not transferred from vault')
                .to.equal(100);
            expect(after.userBalance.sub(before.userBalance).toNumber(), 'Tokens are not transferred to user')
                .to.equal(100);
        });

        it('Withdraw several tokens (no on-hold tokens)', async() => {
            const before = {
                vaultBalance1: await dai.balanceOf(vaultProtocol.address),
                vaultBalance2: await usdc.balanceOf(vaultProtocol.address),
                vaultBalance3: await busd.balanceOf(vaultProtocol.address)
            };

            const withdrawResult = await (<any> vaultProtocol)
                .methods['withdrawFromVault(address,address[],uint256[])'](
                    user2, [dai.address, usdc.address, busd.address], [100, 100, 100], { from: defiops });

            expectEvent(withdrawResult, 'WithdrawFromVault', { _user: user2, _token: dai.address, _amount: '100' });
            expectEvent(withdrawResult, 'WithdrawFromVault', { _user: user2, _token: usdc.address, _amount: '100' });
            expectEvent(withdrawResult, 'WithdrawFromVault', { _user: user2, _token: busd.address, _amount: '100' });
            expectEvent.notEmitted(withdrawResult, 'WithdrawRequestCreated');

            const after = {
                vaultBalance1: await dai.balanceOf(vaultProtocol.address),
                vaultBalance2: await usdc.balanceOf(vaultProtocol.address),
                vaultBalance3: await busd.balanceOf(vaultProtocol.address)
            };

            //Token is transfered to the user
            expect(before.vaultBalance1.sub(after.vaultBalance1).toNumber(), 'Tokens are not transferred from vault')
                .to.equal(100);
            expect(before.vaultBalance2.sub(after.vaultBalance2).toNumber(), 'Tokens are not transferred from vault')
                .to.equal(100);
            expect(before.vaultBalance3.sub(after.vaultBalance3).toNumber(), 'Tokens are not transferred from vault')
                .to.equal(100);
        });

        it('Withdraw several tokens (one of tokens is on-hold)', async() => {
            await dai.transfer(vaultProtocol.address, 50, { from: user2 });
            await (<any> vaultProtocol).methods['depositToVault(address,address,uint256)'](
                user2, dai.address, 50, { from: defiops });

            const onholdBefore = await vaultProtocol.amountOnHold(user2, dai.address);

            const before = {
                vaultBalance1: await dai.balanceOf(vaultProtocol.address),
                vaultBalance2: await usdc.balanceOf(vaultProtocol.address),
                vaultBalance3: await busd.balanceOf(vaultProtocol.address)
            };

            const withdrawResult = await (<any> vaultProtocol)
                .methods['withdrawFromVault(address,address[],uint256[])'](
                    user2, [dai.address, usdc.address, busd.address], [100, 100, 100], { from: defiops });

            expectEvent(withdrawResult, 'WithdrawFromVault', { _user: user2, _token: dai.address, _amount: '100' });
            expectEvent(withdrawResult, 'WithdrawFromVault', { _user: user2, _token: usdc.address, _amount: '100' });
            expectEvent(withdrawResult, 'WithdrawFromVault', { _user: user2, _token: busd.address, _amount: '100' });
            expectEvent.notEmitted(withdrawResult, 'WithdrawRequestCreated');

            const onholdAfter = await vaultProtocol.amountOnHold(user2, dai.address);
            expect(onholdBefore.sub(onholdAfter).toNumber(), 'On-hold deposit was not withdrawn').to.equal(50);

            const after = {
                vaultBalance1: await dai.balanceOf(vaultProtocol.address),
                vaultBalance2: await usdc.balanceOf(vaultProtocol.address),
                vaultBalance3: await busd.balanceOf(vaultProtocol.address)
            };

            //Token is transfered to the user
            expect(before.vaultBalance1.sub(after.vaultBalance1).toNumber(), 'Tokens are not transferred from vault')
                .to.equal(100);
            expect(before.vaultBalance2.sub(after.vaultBalance2).toNumber(), 'Tokens are not transferred from vault')
                .to.equal(100);
            expect(before.vaultBalance3.sub(after.vaultBalance3).toNumber(), 'Tokens are not transferred from vault')
                .to.equal(100);
        });
    });

    describe('Create withdraw request', () => {

        let snap: Snapshot;

        before(async() => {
            await dai.transfer(vaultProtocol.address, 100, { from: user1 });
            await usdc.transfer(vaultProtocol.address, 100, { from: user1 });
            await busd.transfer(vaultProtocol.address, 100, { from: user1 });
            await (<any> vaultProtocol).methods['depositToVault(address,address[],uint256[])'](
                user1, [dai.address, usdc.address, busd.address], [100, 100, 100],
                { from: defiops });

            snap = await Snapshot.create(web3.currentProvider);
        });

        after(async() => await globalSnap.revert());

        afterEach(async() => await snap.revert());

        it('Withdraw token (no on-hold tokens, not enough liquidity)', async() => {
            //Liquidity is withdrawn by another user
            await (<any> vaultProtocol).methods['withdrawFromVault(address,address,uint256)'](
                user3, dai.address, 100, { from: defiops });

            const before = {
                userBalance: await dai.balanceOf(user2),
                vaultBalance: await dai.balanceOf(vaultProtocol.address)
            };

            //User2 tries to withdraw more tokens than are currently on the protocol
            const withdrawResult = await (<any> vaultProtocol)
                .methods['withdrawFromVault(address,address,uint256)'](user2, dai.address, 100, { from: defiops });

            expectEvent(
                withdrawResult, 'WithdrawRequestCreated', { _user: user2, _token: dai.address, _amount: '100' }
            );
            expectEvent.notEmitted(withdrawResult, 'WithdrawFromVault');

            const after = {
                userBalance: await dai.balanceOf(user2),
                vaultBalance: await dai.balanceOf(vaultProtocol.address)
            };

            //Token is not transferred to the user
            expect(before.vaultBalance.toString(), 'Tokens should not be transferred from protocol')
                .to.equal(after.vaultBalance.toString());
            expect(after.userBalance.toString(), 'Tokens should not be transferred to user')
                .to.equal(before.userBalance.toString());

            //User has withdraw request created
            const requestedAmount = await vaultProtocol.amountRequested(user2, dai.address);
            expect(requestedAmount.toNumber(), 'Request should be created').to.equal(100);
        });

        it('Withdraw with on-hold token (not enough liquidity)', async() => {
            const onholdBefore = await vaultProtocol.amountOnHold(user1, dai.address);

            //Liquidity is withdrawn by another user
            await (<any> vaultProtocol).methods['withdrawFromVault(address,address,uint256)'](
                user2, dai.address, 100, { from: defiops });

            const before = {
                userBalance: await dai.balanceOf(user1),
                vaultBalance: await dai.balanceOf(vaultProtocol.address)
            };

            //User1 (with on-hold tokens) tries to withdraw more tokens than are currently on the protocol
            const withdrawResult = await (<any> vaultProtocol)
                .methods['withdrawFromVault(address,address,uint256)'](user1, dai.address, 100, { from: defiops });

            expectEvent(
                withdrawResult, 'WithdrawRequestCreated', { _user: user1, _token: dai.address, _amount: '100' }
            );
            expectEvent.notEmitted(withdrawResult, 'WithdrawFromVault');

            const onholdAfter = await vaultProtocol.amountOnHold(user1, dai.address);

            expect(onholdAfter.toString(), 'On-hold deposit should be left untouched')
                .to.equal(onholdBefore.toString());

            const after = {
                userBalance: await dai.balanceOf(user1),
                vaultBalance: await dai.balanceOf(vaultProtocol.address)
            };

            //Token is not transferred to the user
            expect(before.vaultBalance.toString(), 'Tokens should not be transferred from protocol')
                .to.equal(after.vaultBalance.toString());
            expect(after.userBalance.toString(), 'Tokens should not be transferred to user')
                .to.equal(before.userBalance.toString());

            //Withdraw request created
            const requestedAmount = await vaultProtocol.amountRequested(user1, dai.address);
            expect(requestedAmount.toNumber(), 'Request should be created').to.equal(100);

        });

        it('Withdraw several tokens - not enough liquidity for one of them', async() => {
            //Liquidity is withdrawn by another user
            await (<any> vaultProtocol).methods['withdrawFromVault(address,address,uint256)'](
                user3, dai.address, 100, { from: defiops });

            const before = {
                vaultBalance1: await dai.balanceOf(vaultProtocol.address),
                vaultBalance2: await usdc.balanceOf(vaultProtocol.address),
                vaultBalance3: await busd.balanceOf(vaultProtocol.address)
            };

            const withdrawResult = await (<any> vaultProtocol)
                .methods['withdrawFromVault(address,address[],uint256[])'](
                    user2, [dai.address, usdc.address, busd.address], [100, 100, 100], { from: defiops });

            expectEvent(
                withdrawResult, 'WithdrawRequestCreated', { _user: user2, _token: dai.address, _amount: '100' }
            );
            expectEvent(withdrawResult, 'WithdrawFromVault', { _user: user2, _token: usdc.address, _amount: '100' });
            expectEvent(withdrawResult, 'WithdrawFromVault', { _user: user2, _token: busd.address, _amount: '100' });


            const after = {
                vaultBalance1: await dai.balanceOf(vaultProtocol.address),
                vaultBalance2: await usdc.balanceOf(vaultProtocol.address),
                vaultBalance3: await busd.balanceOf(vaultProtocol.address)
            };

            //1 token is requested, 2 tokens are transfered to the user
            expect(before.vaultBalance1.toString(), 'Tokens are not transferred from vault')
                .to.equal(after.vaultBalance1.toString());
            expect(before.vaultBalance2.sub(after.vaultBalance2).toNumber(), 'Tokens are not transferred from vault')
                .to.equal(100);
            expect(before.vaultBalance3.sub(after.vaultBalance3).toNumber(), 'Tokens are not transferred from vault')
                .to.equal(100);

            //Withdraw request created
            const requestedAmount = await vaultProtocol.amountRequested(user2, dai.address);
            expect(requestedAmount.toNumber(), 'Request should be created').to.equal(100);
        });

    });

    describe('Operator resolves withdraw requests', () => {

        let snap: Snapshot;

        before(async() => {
            await dai.transfer(protocolStub, 1000, { from: owner });
            await usdc.transfer(protocolStub, 1000, { from: owner });
            await busd.transfer(protocolStub, 1000, { from: owner });

            await dai.approve(strategy.address, 1000, { from: protocolStub });
            await usdc.approve(strategy.address, 1000, { from: protocolStub });
            await busd.approve(strategy.address, 1000, { from: protocolStub });

            snap = await Snapshot.create(web3.currentProvider);
        });

        after(async() => await globalSnap.revert());

        afterEach(async() => await snap.revert());

        it('On-hold funds are sent to the protocol', async() => {
            const before = {
                userBalance1: await dai.balanceOf(user1),
                userBalance2: await usdc.balanceOf(user1),
                userBalance3: await busd.balanceOf(user1),
                vaultBalance1: await dai.balanceOf(vaultProtocol.address),
                vaultBalance2: await usdc.balanceOf(vaultProtocol.address),
                vaultBalance3: await busd.balanceOf(vaultProtocol.address),
                protocolBalance1: await dai.balanceOf(protocolStub),
                protocolBalance2: await usdc.balanceOf(protocolStub),
                protocolBalance3: await busd.balanceOf(protocolStub)
            };

            //Imitate LP tokens minting
            await poolToken.mint(user1, 160, { from: defiops });

            await dai.transfer(vaultProtocol.address, 100, { from: user1 });
            await usdc.transfer(vaultProtocol.address, 50, { from: user1 });
            await busd.transfer(vaultProtocol.address, 10, { from: user1 });
            await (<any> vaultProtocol).methods['depositToVault(address,address,uint256)'](
                user1, dai.address, 100, { from: defiops });
            await (<any> vaultProtocol).methods['depositToVault(address,address,uint256)'](
                user1, usdc.address, 50, { from: defiops });
            await (<any> vaultProtocol).methods['depositToVault(address,address,uint256)'](
                user1, busd.address, 10, { from: defiops });

            // withdraw by operator
            const opResult = await vaultProtocol.operatorAction(strategy.address, { from: defiops });
            expectEvent(opResult, 'DepositByOperator', { _amount: '160' });

            await vaultProtocol.clearWithdrawRequests({ from: defiops });
            await vaultProtocol.clearOnHoldDeposits({ from: defiops });

            let onhold = await vaultProtocol.amountOnHold(user1, dai.address);
            expect(onhold.toNumber(), 'On-hold record (1) should be deleted').to.equal(0);
            onhold = await vaultProtocol.amountOnHold(user1, usdc.address);
            expect(onhold.toNumber(), 'On-hold record (2) should be deleted').to.equal(0);
            onhold = await vaultProtocol.amountOnHold(user1, busd.address);
            expect(onhold.toNumber(), 'On-hold record (3) should be deleted').to.equal(0);

            const after = {
                userBalance1: await dai.balanceOf(user1),
                userBalance2: await usdc.balanceOf(user1),
                userBalance3: await busd.balanceOf(user1),
                vaultBalance1: await dai.balanceOf(vaultProtocol.address),
                vaultBalance2: await usdc.balanceOf(vaultProtocol.address),
                vaultBalance3: await busd.balanceOf(vaultProtocol.address),
                protocolBalance1: await dai.balanceOf(protocolStub),
                protocolBalance2: await usdc.balanceOf(protocolStub),
                protocolBalance3: await busd.balanceOf(protocolStub)
            };

            expect(after.vaultBalance1.toNumber(), 'Tokens (1) are not transferred from vault').to.equal(0);
            expect(after.vaultBalance2.toNumber(), 'Tokens (2) are not transferred from vault').to.equal(0);
            expect(after.vaultBalance3.toNumber(), 'Tokens (3) are not transferred from vault').to.equal(0);

            expect(after.protocolBalance1.sub(before.protocolBalance1).toNumber(),
                'Protocol didn\'t receive tokens (1)').to.equal(100);
            expect(after.protocolBalance2.sub(before.protocolBalance2).toNumber(),
                'Protocol didn\'t receive tokens (2)').to.equal(50);
            expect(after.protocolBalance3.sub(before.protocolBalance3).toNumber(),
                'Protocol didn\'t receive tokens (3)').to.equal(10);
        });

        it('Withdraw request is resolved from current liquidity', async() => {
            const before = {
                userBalance1: await dai.balanceOf(user1),
                userBalance2: await usdc.balanceOf(user1),
                userBalance3: await busd.balanceOf(user1),
                vaultBalance1: await dai.balanceOf(vaultProtocol.address),
                vaultBalance2: await usdc.balanceOf(vaultProtocol.address),
                vaultBalance3: await busd.balanceOf(vaultProtocol.address),
                protocolBalance1: await dai.balanceOf(protocolStub),
                protocolBalance2: await usdc.balanceOf(protocolStub),
                protocolBalance3: await busd.balanceOf(protocolStub)
            };

            //Withdraw requests created
            await (<any> vaultProtocol).methods['withdrawFromVault(address,address,uint256)'](
                user1, dai.address, 100, { from: defiops });
            await (<any> vaultProtocol).methods['withdrawFromVault(address,address,uint256)'](
                user1, usdc.address, 50, { from: defiops });
            await (<any> vaultProtocol).methods['withdrawFromVault(address,address,uint256)'](
                user1, busd.address, 10, { from: defiops });

            //Imitate LP tokens minting
            await poolToken.mint(user2, 160, { from: defiops });

            //Deposits to create the exact liquidity
            await dai.transfer(vaultProtocol.address, 100, { from: user2 });
            await usdc.transfer(vaultProtocol.address, 50, { from: user2 });
            await busd.transfer(vaultProtocol.address, 10, { from: user2 });
            await (<any> vaultProtocol).methods['depositToVault(address,address,uint256)'](
                user2, dai.address, 100, { from: defiops });
            await (<any> vaultProtocol).methods['depositToVault(address,address,uint256)'](
                user2, usdc.address, 50, { from: defiops });
            await (<any> vaultProtocol).methods['depositToVault(address,address,uint256)'](
                user2, busd.address, 10, { from: defiops });


            // withdraw by operator
            const opResult = await vaultProtocol.operatorAction(strategy.address, { from: defiops });

            await vaultProtocol.clearWithdrawRequests({ from: defiops });
            await vaultProtocol.clearOnHoldDeposits({ from: defiops });

            expectEvent.notEmitted(opResult, 'WithdrawByOperator');
            expectEvent(opResult, 'WithdrawRequestsResolved');

            //Withdraw requests are resolved
            let requested = await vaultProtocol.amountRequested(user1, dai.address);
            expect(requested.toNumber(), 'Withdraw request (1) should be resolved').to.equal(0);
            requested = await vaultProtocol.amountRequested(user1, usdc.address);
            expect(requested.toNumber(), 'Withdraw request (2) should be resolved').to.equal(0);
            requested = await vaultProtocol.amountRequested(user1, busd.address);
            expect(requested.toNumber(), 'Withdraw request (3) should be resolved').to.equal(0);

            const after = {
                userBalance1: await dai.balanceOf(user1),
                userBalance2: await usdc.balanceOf(user1),
                userBalance3: await busd.balanceOf(user1),
                vaultBalance1: await dai.balanceOf(vaultProtocol.address),
                vaultBalance2: await usdc.balanceOf(vaultProtocol.address),
                vaultBalance3: await busd.balanceOf(vaultProtocol.address),
                protocolBalance1: await dai.balanceOf(protocolStub),
                protocolBalance2: await usdc.balanceOf(protocolStub),
                protocolBalance3: await busd.balanceOf(protocolStub)
            };

            //tokens to claim
            let claimable = await vaultProtocol.claimableAmount(user1, dai.address);
            expect(claimable.toNumber(), 'Cannot claim tokens (1)').to.equal(100);
            claimable = await vaultProtocol.claimableAmount(user1, usdc.address);
            expect(claimable.toNumber(), 'Cannot claim tokens (2)').to.equal(50);
            claimable = await vaultProtocol.claimableAmount(user1, busd.address);
            expect(claimable.toNumber(), 'Cannot claim tokens (3)').to.equal(10);

            expect(after.vaultBalance1.toNumber(), 'No new tokens (1) should be transferred to vault').to.equal(100);
            expect(after.vaultBalance2.toNumber(), 'No new tokens (2) should be transferred to vault').to.equal(50);
            expect(after.vaultBalance3.toNumber(), 'No new tokens (3) should be transferred to vault').to.equal(10);

            expect(before.protocolBalance1.sub(after.protocolBalance1).toNumber(),
                'Protocol should not send tokens (1)').to.equal(0);
            expect(before.protocolBalance2.sub(after.protocolBalance2).toNumber(),
                'Protocol should not send tokens (2)').to.equal(0);
            expect(before.protocolBalance3.sub(after.protocolBalance3).toNumber(),
                'Protocol should not send tokens (3)').to.equal(0);
        });

        it('Withdraw request is resolved with return from protocol', async() => {
            const before = {
                userBalance1: await dai.balanceOf(user1),
                userBalance2: await usdc.balanceOf(user1),
                userBalance3: await busd.balanceOf(user1),
                vaultBalance1: await dai.balanceOf(vaultProtocol.address),
                vaultBalance2: await usdc.balanceOf(vaultProtocol.address),
                vaultBalance3: await busd.balanceOf(vaultProtocol.address),
                protocolBalance1: await dai.balanceOf(protocolStub),
                protocolBalance2: await usdc.balanceOf(protocolStub),
                protocolBalance3: await busd.balanceOf(protocolStub)
            };
            //Withdraw requests created
            await (<any> vaultProtocol).methods['withdrawFromVault(address,address,uint256)'](
                user1, dai.address, 100, { from: defiops });
            await (<any> vaultProtocol).methods['withdrawFromVault(address,address,uint256)'](
                user1, usdc.address, 50, { from: defiops });
            await (<any> vaultProtocol).methods['withdrawFromVault(address,address,uint256)'](
                user1, busd.address, 10, { from: defiops });

            // withdraw by operator
            const opResult = await vaultProtocol.operatorAction(strategy.address, { from: defiops });

            await vaultProtocol.clearWithdrawRequests({ from: defiops });
            await vaultProtocol.clearOnHoldDeposits({ from: defiops });

            expectEvent.notEmitted(opResult, 'DepositByOperator');
            expectEvent(opResult, 'WithdrawRequestsResolved');
            expectEvent(opResult, 'WithdrawByOperator', { _amount: '160' });

            //Withdraw requests are resolved
            let requested = await vaultProtocol.amountRequested(user1, dai.address);
            expect(requested.toNumber(), 'Withdraw request (1) should be resolved').to.equal(0);
            requested = await vaultProtocol.amountRequested(user1, usdc.address);
            expect(requested.toNumber(), 'Withdraw request (2) should be resolved').to.equal(0);
            requested = await vaultProtocol.amountRequested(user1, busd.address);
            expect(requested.toNumber(), 'Withdraw request (3) should be resolved').to.equal(0);

            const after = {
                userBalance1: await dai.balanceOf(user1),
                userBalance2: await usdc.balanceOf(user1),
                userBalance3: await busd.balanceOf(user1),
                vaultBalance1: await dai.balanceOf(vaultProtocol.address),
                vaultBalance2: await usdc.balanceOf(vaultProtocol.address),
                vaultBalance3: await busd.balanceOf(vaultProtocol.address),
                protocolBalance1: await dai.balanceOf(protocolStub),
                protocolBalance2: await usdc.balanceOf(protocolStub),
                protocolBalance3: await busd.balanceOf(protocolStub)
            };

            //tokens to claim
            let claimable = await vaultProtocol.claimableAmount(user1, dai.address);
            expect(claimable.toNumber(), 'Cannot claim tokens (1)').to.equal(100);
            claimable = await vaultProtocol.claimableAmount(user1, usdc.address);
            expect(claimable.toNumber(), 'Cannot claim tokens (2)').to.equal(50);
            claimable = await vaultProtocol.claimableAmount(user1, busd.address);
            expect(claimable.toNumber(), 'Cannot claim tokens (3)').to.equal(10);

            expect(after.vaultBalance1.toNumber(), 'Tokens (1) are not transferred to vault').to.equal(100);
            expect(after.vaultBalance2.toNumber(), 'Tokens (2) are not transferred to vault').to.equal(50);
            expect(after.vaultBalance3.toNumber(), 'Tokens (3) are not transferred to vault').to.equal(10);

            expect(before.protocolBalance1.sub(after.protocolBalance1).toNumber(), 'Protocol didn\'t send tokens (1)')
                .to.equal(100);
            expect(before.protocolBalance2.sub(after.protocolBalance2).toNumber(), 'Protocol didn\'t send tokens (2)')
                .to.equal(50);
            expect(before.protocolBalance3.sub(after.protocolBalance3).toNumber(), 'Protocol didn\'t send tokens (3)')
                .to.equal(10);
        });

        it('Withdraw request is resolved for user with both on-hold and deposited amounts', async() => {
            //In case if there is not enough liquidity to fullfill the request - on-hold amount is left untouched
            //Withdraw should not be fullfilled particulary

            //Create on-hold record
            await dai.transfer(vaultProtocol.address, 100, { from: user1 });
            await (<any> vaultProtocol).methods['depositToVault(address,address,uint256)'](
                user1, dai.address, 100, { from: defiops });

            const before = {
                userBalance: await dai.balanceOf(user1),
                vaultBalance: await dai.balanceOf(vaultProtocol.address),
                protocolBalance: await dai.balanceOf(protocolStub),
            };

            //Withdraw requests created
            await (<any> vaultProtocol).methods['withdrawFromVault(address,address,uint256)'](
                user1, dai.address, 150, { from: defiops });

            // withdraw by operator
            const opResult = await vaultProtocol.operatorAction(strategy.address, { from: defiops });

            await vaultProtocol.clearWithdrawRequests({ from: defiops });
            await vaultProtocol.clearOnHoldDeposits({ from: defiops });

            expectEvent(opResult, 'WithdrawRequestsResolved');
            //On-hold deposit is resolved into claimable
            expectEvent.notEmitted(opResult, 'DepositByOperator');
            //Part of amount is withdrawn from the protocol - other taken from current liquidity
            expectEvent(opResult, 'WithdrawByOperator', { _amount: '50' });

            //Withdraw request is resolved
            const requested = await vaultProtocol.amountRequested(user1, dai.address);
            expect(requested.toNumber(), 'Withdraw request should be resolved').to.equal(0);

            //On-hold record is deleted during the request
            const onhold = await vaultProtocol.amountOnHold(user1, dai.address);
            expect(onhold.toNumber(), 'On-hold record should be deleted').to.equal(0);

            //Total amount is marked as claimed
            const claimable = await vaultProtocol.claimableAmount(user1, dai.address);
            expect(claimable.toNumber(), 'Cannot claim tokens').to.equal(150);

            const after = {
                userBalance: await dai.balanceOf(user1),
                vaultBalance: await dai.balanceOf(vaultProtocol.address),
                protocolBalance: await dai.balanceOf(protocolStub),
            };

            //Since both deposit and withdraw are fullfilled, only (requested - on-hold) is sent from the protocol
            expect(after.vaultBalance.sub(before.vaultBalance).toNumber(), 'Tokens are not transferred to vault')
                .to.equal(50);
            expect(before.protocolBalance.sub(after.protocolBalance).toNumber(), 'Protocol didn\'t send tokens')
                .to.equal(50);
        });
    });

    describe('Claimable tokens functionality', () => {
        let snap: Snapshot;
        before(async() => {
            await dai.approve(strategy.address, 1000, { from: protocolStub });
            await usdc.approve(strategy.address, 1000, { from: protocolStub });
            await busd.approve(strategy.address, 1000, { from: protocolStub });

            //Create some claimable amounts
            await dai.transfer(protocolStub, 180, { from: owner });
            await usdc.transfer(protocolStub, 50, { from: owner });
            await busd.transfer(protocolStub, 20, { from: owner });

            await (<any> vaultProtocol).methods['withdrawFromVault(address,address[],uint256[])'](
                user1, [dai.address, usdc.address, busd.address], [100, 50, 20], { from: defiops });
            await (<any> vaultProtocol).methods['withdrawFromVault(address,address,uint256)'](
                user2, dai.address, 80, { from: defiops });
            await vaultProtocol.operatorAction(strategy.address, { from: defiops });
            await vaultProtocol.clearWithdrawRequests({ from: defiops });
            await vaultProtocol.clearOnHoldDeposits({ from: defiops });


            snap = await Snapshot.create(web3.currentProvider);
        });

        after(async() => await globalSnap.revert());

        afterEach(async() => await snap.revert());

        it('Deposit from user does not influence claimable amount', async() => {
            const claimableBefore = await vaultProtocol.claimableAmount(user1, dai.address);
            const claimableTotalBefore = await vaultProtocol.totalClaimableAmount(dai.address);

            await dai.transfer(vaultProtocol.address, 150, { from: user1 });
            await (<any> vaultProtocol).methods['depositToVault(address,address,uint256)'](
                user1, dai.address, 150, { from: defiops });

            const claimableAfter = await vaultProtocol.claimableAmount(user1, dai.address);
            const claimableTotalAfter = await vaultProtocol.totalClaimableAmount(dai.address);

            expect(claimableBefore.toString(), 'Claimable tokens amount changed').to.equal(claimableAfter.toString());
            expect(claimableTotalBefore.toString(), 'Total claimable tokens amount changed')
                .to.equal(claimableTotalAfter.toString());
        });

        it('Withdraw by user (from liquidity on vault) does not influence claimable amount', async() => {
            //Create some liquidity in the vault
            await dai.transfer(vaultProtocol.address, 200, { from: user3 });
            await (<any> vaultProtocol).methods['depositToVault(address,address,uint256)'](
                user3, dai.address, 200, { from: defiops });

            const claimableBefore = await vaultProtocol.claimableAmount(user1, dai.address);
            const claimableTotalBefore = await vaultProtocol.totalClaimableAmount(dai.address);

            const opResult = await (<any> vaultProtocol).methods['withdrawFromVault(address,address,uint256)'](
                user1, dai.address, 100, { from: defiops });
            expectEvent.notEmitted(opResult, 'WithdrawRequestCreated');
            expectEvent(opResult, 'WithdrawFromVault', { _user: user1, _token: dai.address, _amount: '100' });

            const claimableAfter = await vaultProtocol.claimableAmount(user1, dai.address);
            const claimableTotalAfter = await vaultProtocol.totalClaimableAmount(dai.address);

            //Since withdraw with enough liquidity is already tested, we need to check the claimable amount
            expect(claimableBefore.toString(), 'Claimable tokens amount changed').to.equal(claimableAfter.toString());
            expect(claimableTotalBefore.toString(), 'Total claimable tokens amount changed')
                .to.equal(claimableTotalAfter.toString());
        });

        it('Withdraw does not influence claimable amount, withdraw request is created', async() => {
            //There is not enough liquidity in the vault
            const claimableBefore = await vaultProtocol.claimableAmount(user1, dai.address);
            const claimableTotalBefore = await vaultProtocol.totalClaimableAmount(dai.address);

            const opResult = await (<any> vaultProtocol)
                .methods['withdrawFromVault(address,address,uint256)'](user1, dai.address, 100, { from: defiops });
            expectEvent(opResult, 'WithdrawRequestCreated');

            const claimableAfter = await vaultProtocol.claimableAmount(user1, dai.address);
            const claimableTotalAfter = await vaultProtocol.totalClaimableAmount(dai.address);

            expect(claimableBefore.toString(), 'Claimable tokens amount changed').to.equal(claimableAfter.toString());
            expect(claimableTotalBefore.toString(), 'Total claimable tokens amount changed')
                .to.equal(claimableTotalAfter.toString());
        });

        it('Deposit by operator does not influence claimable tokens', async() => {
            //Create on-hold record to be resolved
            await dai.transfer(vaultProtocol.address, 80, { from: user1 });
            await (<any> vaultProtocol).methods['depositToVault(address,address,uint256)'](
                user1, dai.address, 80, { from: defiops });

            const claimableBefore = await vaultProtocol.claimableAmount(user1, dai.address);
            const claimableTotalBefore = await vaultProtocol.totalClaimableAmount(dai.address);

            const opResult = await vaultProtocol.operatorAction(strategy.address, { from: defiops });
            await vaultProtocol.clearWithdrawRequests({ from: defiops });
            await vaultProtocol.clearOnHoldDeposits({ from: defiops });

            //On-hold tokens are deposited
            expectEvent(opResult, 'DepositByOperator');

            const claimableAfter = await vaultProtocol.claimableAmount(user1, dai.address);
            const claimableTotalAfter = await vaultProtocol.totalClaimableAmount(dai.address);

            expect(claimableBefore.toString(), 'Claimable tokens amount changed').to.equal(claimableAfter.toString());
            expect(claimableTotalBefore.toString(), 'Total claimable tokens amount changed')
                .to.equal(claimableTotalAfter.toString());
        });

        it('Withdraw request resolving increases claimable amount', async() => {
            await dai.transfer(protocolStub, 100, { from: owner });
            await (<any> vaultProtocol).methods['withdrawFromVault(address,address,uint256)'](
                user1, dai.address, 100, { from: defiops });

            const claimableBefore = await vaultProtocol.claimableAmount(user1, dai.address);
            const claimableTotalBefore = await vaultProtocol.totalClaimableAmount(dai.address);

            const opResult = await vaultProtocol.operatorAction(strategy.address, { from: defiops });
            await vaultProtocol.clearWithdrawRequests({ from: defiops });
            await vaultProtocol.clearOnHoldDeposits({ from: defiops });

            //Additional amount requested
            expectEvent(opResult, 'WithdrawByOperator');

            const claimableAfter = await vaultProtocol.claimableAmount(user1, dai.address);
            const claimableTotalAfter = await vaultProtocol.totalClaimableAmount(dai.address);

            //Increases by requested amount
            expect(claimableAfter.sub(claimableBefore).toNumber(), 'Claimable tokens amount not changed').to.equal(100);
            expect(claimableTotalAfter.sub(claimableTotalBefore).toNumber(),
                'Total claimable tokens amount not changed').to.equal(100);
        });

        it('User claims all available tokens', async() => {
            const before = {
                userBalance1: await dai.balanceOf(user1),
                userBalance2: await usdc.balanceOf(user1),
                userBalance3: await busd.balanceOf(user1),
                vaultBalance1: await dai.balanceOf(vaultProtocol.address),
                vaultBalance2: await usdc.balanceOf(vaultProtocol.address),
                vaultBalance3: await busd.balanceOf(vaultProtocol.address),
                claimableTotal1: await vaultProtocol.totalClaimableAmount(dai.address),
                claimableTotal2: await vaultProtocol.totalClaimableAmount(usdc.address),
                claimableTotal3: await vaultProtocol.totalClaimableAmount(busd.address)
            };

            await vaultProtocol.claimRequested(user1, { from: user1 });

            const after = {
                userBalance1: await dai.balanceOf(user1),
                userBalance2: await usdc.balanceOf(user1),
                userBalance3: await busd.balanceOf(user1),
                vaultBalance1: await dai.balanceOf(vaultProtocol.address),
                vaultBalance2: await usdc.balanceOf(vaultProtocol.address),
                vaultBalance3: await busd.balanceOf(vaultProtocol.address),
                claimable1: await vaultProtocol.claimableAmount(user1, dai.address),
                claimable2: await vaultProtocol.claimableAmount(user1, usdc.address),
                claimable3: await vaultProtocol.claimableAmount(user1, busd.address),
                claimableTotal1: await vaultProtocol.totalClaimableAmount(dai.address),
                claimableTotal2: await vaultProtocol.totalClaimableAmount(usdc.address),
                claimableTotal3: await vaultProtocol.totalClaimableAmount(busd.address)
            };

            expect(after.claimable1.toNumber(), 'Not all tokens (1) are claimed').to.equal(0);
            expect(after.claimable2.toNumber(), 'Not all tokens (2) are claimed').to.equal(0);
            expect(after.claimable3.toNumber(), 'Not all tokens (3) are claimed').to.equal(0);

            expect(after.userBalance1.sub(before.userBalance1).toNumber(), 'Tokens (1) are not claimed to user')
                .to.equal(100);
            expect(after.userBalance2.sub(before.userBalance2).toNumber(), 'Tokens (2) are not claimed to user')
                .to.equal(50);
            expect(after.userBalance3.sub(before.userBalance3).toNumber(), 'Tokens (3) are not claimed to user')
                .to.equal(20);

            expect(before.vaultBalance1.sub(after.vaultBalance1).toNumber(), 'Tokens (1) are not claimed from vault')
                .to.equal(100);
            expect(before.vaultBalance2.sub(after.vaultBalance2).toNumber(), 'Tokens (2) are not claimed to vault')
                .to.equal(50);
            expect(before.vaultBalance3.sub(after.vaultBalance3).toNumber(), 'Tokens (3) are not claimed to vault')
                .to.equal(20);

            expect(before.claimableTotal1.sub(after.claimableTotal1).toNumber(), 'Tokens (1) total is not changed')
                .to.equal(100);
            expect(before.claimableTotal2.sub(after.claimableTotal2).toNumber(), 'Tokens (2) total is not changed')
                .to.equal(50);
            expect(before.claimableTotal3.sub(after.claimableTotal3).toNumber(), 'Tokens (3) total is not changed')
                .to.equal(20);
        });

        it('Claim by user does not influence other users claims', async() => {
            const claimableBefore = await vaultProtocol.claimableAmount(user2, dai.address);
            const claimableTotalBefore = await vaultProtocol.totalClaimableAmount(dai.address);

            await vaultProtocol.claimRequested(user1, { from: user1 });

            const claimableAfter = await vaultProtocol.claimableAmount(user2, dai.address);
            const claimableTotalAfter = await vaultProtocol.totalClaimableAmount(dai.address);

            expect(claimableAfter.toString(), 'Claimable tokens amount should not be changed for other users')
                .to.equal(claimableBefore.toString());
            expect(claimableTotalBefore.sub(claimableTotalAfter).toNumber(),
                'Total claimable tokens amount not changed').to.equal(100);
        });

        it('Total claimable calculated correctly', async() => {
            //[180, 50, 20] - initial from before()
            // + additional
            await dai.transfer(protocolStub, 50, { from: user1 });
            await usdc.transfer(protocolStub, 80, { from: user1 });
            await busd.transfer(protocolStub, 180, { from: user1 });
            await (<any> vaultProtocol).methods['withdrawFromVault(address,address,uint256)'](
                user1, dai.address, 50, { from: defiops });
            await (<any> vaultProtocol).methods['withdrawFromVault(address,address,uint256)'](
                user2, usdc.address, 80, { from: defiops });
            await (<any> vaultProtocol).methods['withdrawFromVault(address,address,uint256)'](
                user3, busd.address, 180, { from: defiops });

            await vaultProtocol.operatorAction(strategy.address, { from: defiops });
            await vaultProtocol.clearWithdrawRequests({ from: defiops });
            await vaultProtocol.clearOnHoldDeposits({ from: defiops });


            const claimable1 = await vaultProtocol.totalClaimableAmount(dai.address);
            const claimable2 = await vaultProtocol.totalClaimableAmount(usdc.address);
            const claimable3 = await vaultProtocol.totalClaimableAmount(busd.address);

            expect(claimable1.toNumber(), 'Incorrect total claimable (1)').to.equal(230);
            expect(claimable2.toNumber(), 'Incorrect total claimable (2)').to.equal(130);
            expect(claimable3.toNumber(), 'Incorrect total claimable (3)').to.equal(200);
        });

        it('Event generated after claim', async() => {
            await dai.transfer(protocolStub, 50, { from: user3 });
            await usdc.transfer(protocolStub, 80, { from: user3 });
            await busd.transfer(protocolStub, 100, { from: user3 });
            await (<any> vaultProtocol).methods['withdrawFromVault(address,address[],uint256[])'](
                user3, [dai.address, usdc.address, busd.address], [50, 80, 100], { from: defiops });

            await vaultProtocol.operatorAction(strategy.address, { from: defiops });

            const res = await vaultProtocol.claimRequested(user3, { from: user1 });

            expectEvent(res, 'Claimed', { _vault: vaultProtocol.address, _user: user3, _token: dai.address, _amount: '50' });
            expectEvent(res, 'Claimed', { _vault: vaultProtocol.address, _user: user3, _token: usdc.address, _amount: '80' });
            expectEvent(res, 'Claimed', { _vault: vaultProtocol.address, _user: user3, _token: busd.address, _amount: '100' });
        });
    });

    describe('Full cycle', () => {

        let localSnap: Snapshot;

        before(async() => {
            await dai.approve(strategy.address, 5000, { from: protocolStub });
            await usdc.approve(strategy.address, 5000, { from: protocolStub });
            await busd.approve(strategy.address, 5000, { from: protocolStub });
            await usdt.approve(strategy.address, 5000, { from: protocolStub });

            localSnap = await Snapshot.create(web3.currentProvider);
        });

        after(async() => await globalSnap.revert());

        afterEach(async() => await localSnap.revert());

        it('All deposited funds plus yeild equal to all withdrawn funds', async() => {
            const sent = {
                user1: { dai: 15, usdc: 50, usdt: 100 },
                user2: { dai: 20, usdc: 80 },
                user3: { dai: 50, usdc: 20, busd: 50, usdt: 50 },
            };
            const vaultBalancesBefore = {
                dai: await dai.balanceOf(vaultProtocol.address),
                usdc: await usdc.balanceOf(vaultProtocol.address),
                busd: await busd.balanceOf(vaultProtocol.address),
                usdt: await usdt.balanceOf(vaultProtocol.address)
            };
            const onHoldBefore = {
                user1: {
                    dai: await vaultProtocol.amountOnHold(user1, dai.address),
                    usdc: await vaultProtocol.amountOnHold(user1, usdc.address),
                    busd: await vaultProtocol.amountOnHold(user1, busd.address),
                    usdt: await vaultProtocol.amountOnHold(user1, usdt.address),
                },
                user2: {
                    dai: await vaultProtocol.amountOnHold(user2, dai.address),
                    usdc: await vaultProtocol.amountOnHold(user2, usdc.address),
                    busd: await vaultProtocol.amountOnHold(user2, busd.address),
                    usdt: await vaultProtocol.amountOnHold(user2, usdt.address),
                },
                user3: {
                    dai: await vaultProtocol.amountOnHold(user3, dai.address),
                    usdc: await vaultProtocol.amountOnHold(user3, usdc.address),
                    busd: await vaultProtocol.amountOnHold(user3, busd.address),
                    usdt: await vaultProtocol.amountOnHold(user3, usdt.address),
                },
            };
            const totalByUser = {
                user1: sent.user1.dai + sent.user1.usdc + sent.user1.usdt,
                user2: sent.user2.dai + sent.user2.usdc,
                user3: sent.user3.dai + sent.user3.usdc + sent.user3.busd + sent.user3.usdt
            };
            const balanceBefore = {
                user1: {
                    dai: await dai.balanceOf(user1),
                    usdc: await usdc.balanceOf(user1),
                    busd: await busd.balanceOf(user1),
                    usdt: await usdt.balanceOf(user1),
                },
                user2: {
                    dai: await dai.balanceOf(user2),
                    usdc: await usdc.balanceOf(user2),
                    busd: await busd.balanceOf(user2),
                    usdt: await usdt.balanceOf(user2),
                },
                user3: {
                    dai: await dai.balanceOf(user3),
                    usdc: await usdc.balanceOf(user3),
                    busd: await busd.balanceOf(user3),
                    usdt: await usdt.balanceOf(user3),
                },
            };

            /**************************
             * 1. Users make deposits *
             *************************/
            // First deposits from 3 users
            // Deposits from user1
            await dai.transfer(vaultProtocol.address, sent.user1.dai, { from: user1 });
            await usdc.transfer(vaultProtocol.address, sent.user1.usdc, { from: user1 });
            await usdt.transfer(vaultProtocol.address, sent.user1.usdt, { from: user1 });
            await vaultProtocol.methods['depositToVault(address,address[],uint256[])'](user1,
                [dai.address, usdc.address, usdt.address], Object.values(sent.user1), { from: defiops });
            // Send the same amount of pool tokens for user stablecoins
            await poolToken.mint(user1, totalByUser.user1, { from: defiops });

            // Deposits from user2
            await dai.transfer(vaultProtocol.address, sent.user2.dai, { from: user2 });
            await usdc.transfer(vaultProtocol.address, sent.user2.usdc, { from: user2 });
            await vaultProtocol.methods['depositToVault(address,address[],uint256[])'](user2,
                [dai.address, usdc.address], Object.values(sent.user2), { from: defiops });
            // Send the same amount of pool tokens for user stablecoins
            await poolToken.mint(user2, totalByUser.user2, { from: defiops });

            // Deposits from user3
            await dai.transfer(vaultProtocol.address, sent.user3.dai, { from: user3 });
            await usdc.transfer(vaultProtocol.address, sent.user3.usdc, { from: user3 });
            await busd.transfer(vaultProtocol.address, sent.user3.busd, { from: user3 });
            await usdt.transfer(vaultProtocol.address, sent.user3.usdt, { from: user3 });
            await vaultProtocol.methods['depositToVault(address,address[],uint256[])'](user3,
                [dai.address, usdc.address, busd.address, usdt.address], Object.values(sent.user3), { from: defiops });
            // Send the same amount of pool tokens for user stablecoins
            await poolToken.mint(user3, totalByUser.user3, { from: defiops });

            // Valut receives tokens
            const vaultBalancesAfter = {
                dai: await dai.balanceOf(vaultProtocol.address),
                usdc: await usdc.balanceOf(vaultProtocol.address),
                busd: await busd.balanceOf(vaultProtocol.address),
                usdt: await usdt.balanceOf(vaultProtocol.address)
            };
            const onHoldAfter = {
                user1: {
                    dai: await vaultProtocol.amountOnHold(user1, dai.address),
                    usdc: await vaultProtocol.amountOnHold(user1, usdc.address),
                    usdt: await vaultProtocol.amountOnHold(user1, usdt.address),
                },
                user2: {
                    dai: await vaultProtocol.amountOnHold(user2, dai.address),
                    usdc: await vaultProtocol.amountOnHold(user2, usdc.address),
                },
                user3: {
                    dai: await vaultProtocol.amountOnHold(user3, dai.address),
                    usdc: await vaultProtocol.amountOnHold(user3, usdc.address),
                    busd: await vaultProtocol.amountOnHold(user3, busd.address),
                    usdt: await vaultProtocol.amountOnHold(user3, usdt.address),
                },
            };
            const totalByToken = {
                dai: sent.user1.dai + sent.user2.dai + sent.user3.dai,
                usdc: sent.user1.usdc + sent.user2.usdc + sent.user3.usdc,
                busd: sent.user3.busd,
                usdt: sent.user1.usdt + sent.user3.usdt
            };

            expect(onHoldAfter.user1.dai.sub(onHoldBefore.user1.dai).toNumber(),
                'User1: on hold DAI amount should change').to.equal(sent.user1.dai);
            expect(onHoldAfter.user1.usdc.sub(onHoldBefore.user1.usdc).toNumber(),
                'User1: on hold USDC amount should change').to.equal(sent.user1.usdc);
            expect(onHoldAfter.user1.usdt.sub(onHoldBefore.user1.usdt).toNumber(),
                'User1: on hold USDT amount should change').to.equal(sent.user1.usdt);

            expect(onHoldAfter.user2.dai.sub(onHoldBefore.user2.dai).toNumber(),
                'User2: on hold DAI amount should change').to.equal(sent.user2.dai);
            expect(onHoldAfter.user2.usdc.sub(onHoldBefore.user2.usdc).toNumber(),
                'User2: on hold USDC amount should change').to.equal(sent.user2.usdc);

            expect(onHoldAfter.user3.dai.sub(onHoldBefore.user3.dai).toNumber(),
                'User3: on hold DAI amount should change').to.equal(sent.user3.dai);
            expect(onHoldAfter.user3.usdc.sub(onHoldBefore.user3.usdc).toNumber(),
                'User3: on hold USDC amount should change').to.equal(sent.user3.usdc);
            expect(onHoldAfter.user3.busd.sub(onHoldBefore.user3.busd).toNumber(),
                'User3: on hold BUSD amount should change').to.equal(sent.user3.busd);
            expect(onHoldAfter.user3.usdt.sub(onHoldBefore.user3.usdt).toNumber(),
                'User3: on hold USDT amount should change').to.equal(sent.user3.usdt);

            expect(vaultBalancesAfter.dai.sub(vaultBalancesBefore.dai).toNumber(),
                'Vault: on hold DAI amount should change').to.equal(totalByToken.dai);
            expect(vaultBalancesAfter.usdc.sub(vaultBalancesBefore.usdc).toNumber(),
                'Vault: on hold USDC amount should change').to.equal(totalByToken.usdc);
            expect(vaultBalancesAfter.busd.sub(vaultBalancesBefore.busd).toNumber(),
                'Vault: on hold BUSD amount should change').to.equal(totalByToken.busd);
            expect(vaultBalancesAfter.usdt.sub(vaultBalancesBefore.usdt).toNumber(),
                'Vault: on hold USDT amount should change').to.equal(totalByToken.usdt);

            // Operator resolves deposits to the strategy
            const stubBalanceBeforeAction = {
                dai: await dai.balanceOf(protocolStub),
                usdc: await usdc.balanceOf(protocolStub),
                busd: await busd.balanceOf(protocolStub),
                usdt: await usdt.balanceOf(protocolStub),
            };

            await vaultProtocol.operatorAction(strategy.address, { from: defiops });

            const stubBalanceAfterAction = {
                dai: await dai.balanceOf(protocolStub),
                usdc: await usdc.balanceOf(protocolStub),
                busd: await busd.balanceOf(protocolStub),
                usdt: await usdt.balanceOf(protocolStub),
            };

            expect(stubBalanceAfterAction.dai.sub(stubBalanceBeforeAction.dai).toNumber(),
                'All DAI should be on the strategy').to.equal(totalByToken.dai);
            expect(stubBalanceAfterAction.usdc.sub(stubBalanceBeforeAction.usdc).toNumber(),
                'All USDC should be on the strategy').to.equal(totalByToken.usdc);
            expect(stubBalanceAfterAction.busd.sub(stubBalanceBeforeAction.busd).toNumber(),
                'All BUSD should be on the strategy').to.equal(totalByToken.busd);
            expect(stubBalanceAfterAction.usdt.sub(stubBalanceBeforeAction.usdt).toNumber(),
                'All USDT should be on the strategy').to.equal(totalByToken.usdt);

            /*************************
             * 2. Yield is generated *
             ************************/
            // Add some yields to the protocol
            const yields = { dai: 10, usdc: 20, busd: 30, usdt: 40 };
            
            // Transfer yield
            await dai.transfer(protocolStub, yields.dai, { from: owner });
            await usdc.transfer(protocolStub, yields.usdc, { from: owner });
            await busd.transfer(protocolStub, yields.busd, { from: owner });
            await usdt.transfer(protocolStub, yields.usdt, { from: owner });

            // Hardcode profits for users
            const profits = {
                user1: { dai: 7, usdc: 14, usdt: 15 },
                user2: { dai: 1, usdc: 3, busd: 10 },
                user3: { dai: 2, usdc: 3, busd: 20, usdt: 25 },
            };

            /*****************************************
             * 3. Some withdraws, some deposits more *
             ****************************************/
            // Put enough DAI for user2 but not for user3
            const toUser2 = sent.user2.dai + profits.user2.dai;
            const toUser3 = sent.user3.dai + profits.user3.dai;
            const values = { dai: toUser2 + toUser3 - 1 };
            
            await dai.transfer(vaultProtocol.address, values.dai, { from: user1 });
            await vaultProtocol.methods['depositToVault(address,address[],uint256[])'](
                user1, [dai.address], [values.dai], { from: defiops });
            await poolToken.mint(user1, values.dai, { from: defiops });

            const before = {
                user2: await dai.balanceOf(user2),
                user3: await dai.balanceOf(user3),
                vault: await dai.balanceOf(vaultProtocol.address)
            };

            // Withdraws DAI successfully
            await vaultProtocol.methods['withdrawFromVault(address,address,uint256)'](
                user2, dai.address, toUser2, { from: defiops });

            // Ask to withdraw DAI when the contract doesn't have enough of them
            await vaultProtocol.methods['withdrawFromVault(address,address,uint256)'](
                user3, dai.address, toUser3, { from: defiops });

            const requested = {
                user2: await vaultProtocol.amountRequested(user2, dai.address),
                user3: await vaultProtocol.amountRequested(user3, dai.address)
            };
            const claimable = { user3: await vaultProtocol.claimableAmount(user3, dai.address) };
            const after = {
                user2: await dai.balanceOf(user2),
                user3: await dai.balanceOf(user3),
                vault: await dai.balanceOf(vaultProtocol.address)
            };

            expect(after.user2.sub(before.user2).toNumber(), 'User2: should successfully withdraw').to.equal(toUser2);
            expect(requested.user2.toNumber(), 'User2: shouldn\'t have a requested amount').to.equal(0);
            expect(after.user3.sub(before.user3).toNumber(), 'User3: balance shouldn\'t change').to.equal(0);
            expect(requested.user3.toNumber(), 'User3: requested amount should be as in withdraw').to.equal(toUser3);
            expect(claimable.user3.toNumber(), 'User3: shouldn\'t have a claimable amount').to.equal(0);
            expect(before.vault.sub(after.vault).toNumber()).to.equal(toUser2);

            // Put enough DAI for the user3 to the vault
            await dai.transfer(vaultProtocol.address, 1, { from: user1 });
            await vaultProtocol.methods['depositToVault(address,address[],uint256[])'](
                user1, [dai.address], [1], { from: defiops });
            await poolToken.mint(user1, 1, { from: defiops });
            
            // Call operator action
            const user3BalanceBefore = await dai.balanceOf(user3);
            await vaultProtocol.operatorAction(strategy.address, { from: defiops });

            const user3Stat = {
                requested: await vaultProtocol.amountRequested(user3, dai.address),
                claimable: await vaultProtocol.claimableAmount(user3, dai.address)
            };

            // Now the stablecoins could be withdrawn
            expect(user3Stat.claimable.toNumber(), 'User3: claimable amount should be as in withdraw')
                .to.equal(toUser3);
            expect(user3Stat.requested.toNumber(), 'User3: requested amount should be zero').to.equal(0);

            // Withdraw
            await vaultProtocol.claimRequested(user3, { from: user3 });
            const user3BalanceAfter = await dai.balanceOf(user3);

            expect(user3BalanceAfter.sub(user3BalanceBefore).toNumber(), 'User3: all tokens should be withdrawn')
                .to.equal(toUser3);

            // User1 asks to withdraw DAI when the contract doesn't have enough of them
            const toUser1 = sent.user1.dai + profits.user1.dai + values.dai + 1;
            await vaultProtocol.methods['withdrawFromVault(address,address,uint256)'](
                user1, dai.address, toUser1, { from: defiops });

            await vaultProtocol.operatorAction(strategy.address, { from: defiops });

            // User1 deposits more
            const sendMore = { user1: { dai: 30 } };
            await dai.transfer(vaultProtocol.address, sendMore.user1.dai, { from: user1 });
            await vaultProtocol.methods['depositToVault(address,address,uint256)'](
                user1, dai.address, sendMore.user1.dai, { from: defiops });
            await poolToken.mint(user2, sendMore.user1.dai, { from: defiops });

            await vaultProtocol.operatorAction(strategy.address, { from: defiops });

            // Withdraws DAI successfully
            const user1BalanceBefore = await dai.balanceOf(user1);
            await vaultProtocol.methods['withdrawFromVault(address,address,uint256)'](
                user1, dai.address, sendMore.user1.dai, { from: defiops });
            await vaultProtocol.operatorAction(strategy.address, { from: defiops });
            await vaultProtocol.claimRequested(user1, { from: user1 });

            const user1BalanceAfter = await dai.balanceOf(user1);

            expect(user1BalanceAfter.sub(user1BalanceBefore).toNumber(),
                'User1: all DAI should be withdrawn').to.equal(toUser1 + sendMore.user1.dai);

            /************************************************
             * 4. More deposits but without operator action *
             ***********************************************/
            // Deposits from users 1 & 2
            const more = {
                user1: { usdc: 15, usdt: 100 },
                user2: { dai: 50 },
            };
            await usdc.transfer(vaultProtocol.address, more.user1.usdc, { from: user1 });
            await usdt.transfer(vaultProtocol.address, more.user1.usdt, { from: user1 });
            await vaultProtocol.methods['depositToVault(address,address[],uint256[])'](user1,
                [usdc.address, usdt.address], Object.values(more.user1), { from: defiops });
            // Send the same amount of pool tokens for user stablecoins
            await poolToken.mint(user1, Object.values(more.user1).reduce((acc, x) => acc += x), { from: defiops });

            await dai.transfer(vaultProtocol.address, more.user2.dai, { from: user2 });
            await vaultProtocol.methods['depositToVault(address,address[],uint256[])'](user2,
                [dai.address], Object.values(more.user2), { from: defiops });
            // Send the same amount of pool tokens for user stablecoins
            await poolToken.mint(user2, Object.values(more.user2).reduce((acc, x) => acc += x), { from: defiops });

            /*********************************
             * 5. Everyone claims everything *
             ********************************/
            await vaultProtocol.methods['withdrawFromVault(address,address[],uint256[])'](
                user1, [usdc.address, usdt.address],
                [
                    sent.user1.usdc + more.user1.usdc + profits.user1.usdc,
                    sent.user1.usdt + more.user1.usdt + profits.user1.usdt
                ], { from: defiops });
            await vaultProtocol.methods['withdrawFromVault(address,address[],uint256[])'](
                user2, [dai.address, usdc.address, busd.address],
                [
                    more.user2.dai,
                    sent.user2.usdc + profits.user2.usdc,
                    profits.user2.busd,
                ], { from: defiops });
            await vaultProtocol.methods['withdrawFromVault(address,address[],uint256[])'](
                user3, [usdc.address, busd.address, usdt.address],
                [
                    sent.user3.usdc + profits.user3.usdc,
                    sent.user3.busd + profits.user3.busd,
                    sent.user3.usdt + profits.user3.usdt
                ], { from: defiops });

            await vaultProtocol.operatorAction(strategy.address, { from: defiops });

            await vaultProtocol.claimRequested(user1, { from: user1 });
            await vaultProtocol.claimRequested(user2, { from: user2 });
            await vaultProtocol.claimRequested(user3, { from: user3 });

            // clearWithdrawRequests
            const balanceAfter = {
                user1: {
                    dai: await dai.balanceOf(user1),
                    usdc: await usdc.balanceOf(user1),
                    busd: await busd.balanceOf(user1),
                    usdt: await usdt.balanceOf(user1),
                },
                user2: {
                    dai: await dai.balanceOf(user2),
                    usdc: await usdc.balanceOf(user2),
                    busd: await busd.balanceOf(user2),
                    usdt: await usdt.balanceOf(user2),
                },
                user3: {
                    dai: await dai.balanceOf(user3),
                    usdc: await usdc.balanceOf(user3),
                    busd: await busd.balanceOf(user3),
                    usdt: await usdt.balanceOf(user3),
                },
            };

            expect(balanceAfter.user1.dai.toNumber(), 'User1: dai incorrect balance')
                .to.equal(balanceBefore.user1.dai.toNumber() + profits.user1.dai);
            expect(balanceAfter.user1.usdc.toNumber(), 'User1: usdc incorrect balance')
                .to.equal(balanceBefore.user1.usdc.toNumber() + profits.user1.usdc);
            expect(balanceAfter.user1.busd.toNumber(), 'User1: busd incorrect balance')
                .to.equal(balanceBefore.user1.busd.toNumber());
            expect(balanceAfter.user1.usdt.toNumber(), 'User1: usdt incorrect balance')
                .to.equal(balanceBefore.user1.usdt.toNumber() + profits.user1.usdt);

            expect(balanceAfter.user2.dai.toNumber(), 'User2: dai incorrect balance')
                .to.equal(balanceBefore.user2.dai.toNumber() + profits.user2.dai);
            expect(balanceAfter.user2.usdc.toNumber(), 'User2: usdc incorrect balance')
                .to.equal(balanceBefore.user2.usdc.toNumber() + profits.user2.usdc);
            expect(balanceAfter.user2.busd.toNumber(), 'User2: busd incorrect balance')
                .to.equal(balanceBefore.user2.busd.toNumber() + profits.user2.busd);
            expect(balanceAfter.user2.usdt.toNumber(), 'User2: usdt incorrect balance')
                .to.equal(balanceBefore.user2.usdt.toNumber());

            expect(balanceAfter.user3.dai.toNumber(), 'User3: dai incorrect balance')
                .to.equal(balanceBefore.user3.dai.toNumber() + profits.user3.dai);
            expect(balanceAfter.user3.usdc.toNumber(), 'User3: usdc incorrect balance')
                .to.equal(balanceBefore.user3.usdc.toNumber() + profits.user3.usdc);
            expect(balanceAfter.user3.busd.toNumber(), 'User3: busd incorrect balance')
                .to.equal(balanceBefore.user3.busd.toNumber() + profits.user3.busd);
            expect(balanceAfter.user3.usdt.toNumber(), 'User3: usdt incorrect balance')
                .to.equal(balanceBefore.user3.usdt.toNumber() + profits.user3.usdt);

            expect((await dai.balanceOf(vaultProtocol.address)).toNumber(),
                'Vault: DAI balance should be 0').to.equal(0);
            expect((await usdc.balanceOf(vaultProtocol.address)).toNumber(),
                'Vault: USDC balance should be 0').to.equal(0);
            expect((await busd.balanceOf(vaultProtocol.address)).toNumber(),
                'Vault: BUSD balance should be 0').to.equal(0);
            expect((await usdt.balanceOf(vaultProtocol.address)).toNumber(),
                'Vault: USDT balance should be 0').to.equal(0);

            expect((await dai.balanceOf(protocolStub)).toNumber(),
                'Protocol stub: DAI balance should be 0').to.equal(0);
            expect((await usdc.balanceOf(protocolStub)).toNumber(),
                'Protocol stub: DAI balance should be 0').to.equal(0);
            expect((await busd.balanceOf(protocolStub)).toNumber(),
                'Protocol stub: DAI balance should be 0').to.equal(0);
            expect((await usdt.balanceOf(protocolStub)).toNumber(),
                'Protocol stub: DAI balance should be 0').to.equal(0);

            expect((await vaultProtocol.claimableAmount(user1, dai.address)).toNumber(),
                'User1: expect no claimable DAI').to.equal(0);
            expect((await vaultProtocol.claimableAmount(user1, usdc.address)).toNumber(),
                'User1: expect no claimable USDC').to.equal(0);
            expect((await vaultProtocol.claimableAmount(user1, busd.address)).toNumber(),
                'User1: expect no claimable BUSD').to.equal(0);
            expect((await vaultProtocol.claimableAmount(user1, usdt.address)).toNumber(),
                'User1: expect no claimable USDT').to.equal(0);

            expect((await vaultProtocol.claimableAmount(user2, dai.address)).toNumber(),
                'User2: expect no claimable DAI').to.equal(0);
            expect((await vaultProtocol.claimableAmount(user2, usdc.address)).toNumber(),
                'User2: expect no claimable USDC').to.equal(0);
            expect((await vaultProtocol.claimableAmount(user2, busd.address)).toNumber(),
                'User2: expect no claimable BUSD').to.equal(0);
            expect((await vaultProtocol.claimableAmount(user2, usdt.address)).toNumber(),
                'User2: expect no claimable USDT').to.equal(0);

            expect((await vaultProtocol.claimableAmount(user3, dai.address)).toNumber(),
                'User3: expect no claimable DAI').to.equal(0);
            expect((await vaultProtocol.claimableAmount(user3, usdc.address)).toNumber(),
                'User3: expect no claimable USDC').to.equal(0);
            expect((await vaultProtocol.claimableAmount(user3, busd.address)).toNumber(),
                'User3: expect no claimable BUSD').to.equal(0);
            expect((await vaultProtocol.claimableAmount(user3, usdt.address)).toNumber(),
                'User3: expect no claimable USDT').to.equal(0);

            expect((await vaultProtocol.amountOnHold(user1, dai.address)).toNumber(),
                'User1: expect no DAI on hold').to.equal(0);
            expect((await vaultProtocol.amountOnHold(user1, usdc.address)).toNumber(),
                'User1: expect no USDC on hold').to.equal(0);
            expect((await vaultProtocol.amountOnHold(user1, busd.address)).toNumber(),
                'User1: expect no BUSD on hold').to.equal(0);
            expect((await vaultProtocol.amountOnHold(user1, usdt.address)).toNumber(),
                'User1: expect no USDT on hold').to.equal(0);

            expect((await vaultProtocol.amountOnHold(user2, dai.address)).toNumber(),
                'User2: expect no DAI on hold').to.equal(0);
            expect((await vaultProtocol.amountOnHold(user2, usdc.address)).toNumber(),
                'User2: expect no USDC on hold').to.equal(0);
            expect((await vaultProtocol.amountOnHold(user2, busd.address)).toNumber(),
                'User2: expect no BUSD on hold').to.equal(0);
            expect((await vaultProtocol.amountOnHold(user2, usdt.address)).toNumber(),
                'User2: expect no USDT on hold').to.equal(0);

            expect((await vaultProtocol.amountOnHold(user3, dai.address)).toNumber(),
                'User3: expect no DAI on hold').to.equal(0);
            expect((await vaultProtocol.amountOnHold(user3, usdc.address)).toNumber(),
                'User3: expect no USDC on hold').to.equal(0);
            expect((await vaultProtocol.amountOnHold(user3, busd.address)).toNumber(),
                'User3: expect no BUSD on hold').to.equal(0);
            expect((await vaultProtocol.amountOnHold(user3, usdt.address)).toNumber(),
                'User3: expect no USDT on hold').to.equal(0);
        });

    });

    describe('Quick withdraw', () => {
        let localSnap : Snapshot;

        before(async() => {
            await dai.approve(strategy.address, 1000, { from: protocolStub });
            await usdc.approve(strategy.address, 1000, { from: protocolStub });
            await busd.approve(strategy.address, 1000, { from: protocolStub });
            await usdt.approve(strategy.address, 1000, { from: protocolStub });

            await dai.transfer(protocolStub, 1000, { from: owner });
            await usdc.transfer(protocolStub, 1000, { from: owner });
            await busd.transfer(protocolStub, 1000, { from: owner });
            await usdt.transfer(protocolStub, 1000, { from: owner });

            localSnap = await Snapshot.create(web3.currentProvider);
        });

        after(async() => await globalSnap.revert());

        afterEach(async() => await localSnap.revert());

        it('Quick withdraw (has withdraw request)', async() => {
            await vaultProtocol.methods['withdrawFromVault(address,address[],uint256[])'](
                user1, [dai.address], [80], { from: owner });

            const before = {
                invault : await dai.balanceOf(vaultProtocol.address),
                requested : await vaultProtocol.amountRequested(user1, dai.address),
                instrategy : await dai.balanceOf(protocolStub),
                user : await dai.balanceOf(user1)
            };

            await vaultProtocol.quickWithdraw(user1, [120, 0, 0, 0], { from: defiops });

            const after = {
                invault : await dai.balanceOf(vaultProtocol.address),
                requested : await vaultProtocol.amountRequested(user1, dai.address),
                instrategy : await dai.balanceOf(protocolStub),
                user : await dai.balanceOf(user1)
            };

            //Check that Vault liquidity is unchanged
            expect(after.invault.sub(before.invault).toNumber(), "Vault liquidity was changed").to.equal(0);
            //Check that request record is unchanged
            expect(after.requested.sub(before.requested).toNumber(), "Requested amount was changed").to.equal(0);
            //Check that funds are withdraw from the strategy
            expect(after.instrategy.sub(before.instrategy).toNumber(), "Strategy balance was not changed").to.equal(-120);
            //Check that token is trasfered to the user
            expect(after.user.sub(before.user).toNumber(), "User balance was not changed").to.equal(120);
        });

        it('Quick withdraw (enough liquidity)', async() => {
            const before = {
                invault : await dai.balanceOf(vaultProtocol.address),
                instrategy : await dai.balanceOf(protocolStub),
                user : await dai.balanceOf(user1)
            };

            await vaultProtocol.quickWithdraw(user1, [120, 0, 0, 0], { from: defiops });

            const after = {
                invault : await dai.balanceOf(vaultProtocol.address),
                instrategy : await dai.balanceOf(protocolStub),
                user : await dai.balanceOf(user1)
            };

            //Check that Vault liquidity is unchanged
            expect(after.invault.sub(before.invault).toNumber(), "Vault liquidity was changed").to.equal(0);
            //Check that funds are withdraw from the strategy
            expect(after.instrategy.sub(before.instrategy).toNumber(), "Strategy balance was not changed").to.equal(-120);
            //Check that token is trasfered to the user
            expect(after.user.sub(before.user).toNumber(), "User balance was not changed").to.equal(120);
        });

        it('Quick withdraw (has on-hold token, enough liquidity)', async() => {
            await vaultProtocol.methods['depositToVault(address,address[],uint256[])'](user1,
                [dai.address], [140], { from: defiops });

            const before = {
                invault : await dai.balanceOf(vaultProtocol.address),
                onhold : await vaultProtocol.amountOnHold(user1, dai.address),
                instrategy : await dai.balanceOf(protocolStub),
                user : await dai.balanceOf(user1)
            };

            await vaultProtocol.quickWithdraw(user1, [120, 0, 0, 0], { from: defiops });

            const after = {
                invault : await dai.balanceOf(vaultProtocol.address),
                onhold : await vaultProtocol.amountOnHold(user1, dai.address),
                instrategy : await dai.balanceOf(protocolStub),
                user : await dai.balanceOf(user1)
            };

            //Check that Vault liquidity is unchanged
            expect(after.invault.sub(before.invault).toNumber(), "Vault liquidity was changed").to.equal(0);
            //Check that on-hold record is unchanged
            expect(after.onhold.sub(before.onhold).toNumber(), "On-hold amount was changed").to.equal(0);
            //Check that funds are withdraw from the strategy
            expect(after.instrategy.sub(before.instrategy).toNumber(), "Strategy balance was not changed").to.equal(-120);
            //Check that token is trasfered to the user
            expect(after.user.sub(before.user).toNumber(), "User balance was not changed").to.equal(120);
        });

        it('Quick withdraw (has on-hold token, not enough liquidity)', async() => {
            await vaultProtocol.methods['depositToVault(address,address[],uint256[])'](user1,
                [dai.address], [80], { from: defiops });

            const before = {
                invault : await dai.balanceOf(vaultProtocol.address),
                onhold : await vaultProtocol.amountOnHold(user1, dai.address),
                instrategy : await dai.balanceOf(protocolStub),
                user : await dai.balanceOf(user1)
            };

            await vaultProtocol.quickWithdraw(user1, [120, 0, 0, 0], { from: defiops });

            const after = {
                invault : await dai.balanceOf(vaultProtocol.address),
                onhold : await vaultProtocol.amountOnHold(user1, dai.address),
                instrategy : await dai.balanceOf(protocolStub),
                user : await dai.balanceOf(user1)
            };

            //Check that Vault liquidity is unchanged
            expect(after.invault.sub(before.invault).toNumber(), "Vault liquidity was changed").to.equal(0);
            //Check that on-hold record is unchanged
            expect(after.onhold.sub(before.onhold).toNumber(), "On-hold amount was changed").to.equal(0);
            //Check that funds are withdraw from the strategy
            expect(after.instrategy.sub(before.instrategy).toNumber(), "Strategy balance was not changed").to.equal(-120);
            //Check that token is trasfered to the user
            expect(after.user.sub(before.user).toNumber(), "User balance was not changed").to.equal(120);
        });

        it('Quick withdraw (not enough liquidity)', async() => {
            const before = {
                invault : await dai.balanceOf(vaultProtocol.address),
                instrategy : await dai.balanceOf(protocolStub),
                user : await dai.balanceOf(user1)
            };

            await vaultProtocol.quickWithdraw(user1, [120, 0, 0, 0], { from: defiops });

            const after = {
                invault : await dai.balanceOf(vaultProtocol.address),
                instrategy : await dai.balanceOf(protocolStub),
                user : await dai.balanceOf(user1)
            };

            //Check that Vault liquidity is unchanged
            expect(after.invault.sub(before.invault).toNumber(), "Vault liquidity was changed").to.equal(0);
            //Check that funds are withdraw from the strategy
            expect(after.instrategy.sub(before.instrategy).toNumber(), "Strategy balance was not changed").to.equal(-120);
            //Check that token is trasfered to the user
            expect(after.user.sub(before.user).toNumber(), "User balance was not changed").to.equal(120);
        });

    });

    describe('Registered tokens only', () => {

        async function vaultSetup(tokens: Array<string>) {
            const _vaultProtocol = await VaultProtocol.new({ from: owner });
            await (<any>_vaultProtocol).methods['initialize(address,address[])'](pool.address, tokens, { from: owner });
            await _vaultProtocol.addDefiOperator(defiops, { from: owner });
            //------
            const _poolToken = await PoolToken.new({ from: owner });
            await (<any>_poolToken).methods['initialize(address,string,string)'](
                pool.address, 'VaultSavings', 'VLT', { from: owner });

            await _poolToken.addMinter(vaultSavings.address, { from: owner });
            await _poolToken.addMinter(_vaultProtocol.address, { from: owner });
            await _poolToken.addMinter(defiops, { from: owner });
            //------
            const _strategy = await VaultStrategy.new({ from: owner });
            await (<any>_strategy).methods['initialize(string)']('1', { from: owner });
            await _strategy.setProtocol(protocolStub, { from: owner });

            await _strategy.addDefiOperator(defiops, { from: owner });
            await _strategy.addDefiOperator(_vaultProtocol.address, { from: owner });
            //------
            await _vaultProtocol.registerStrategy(_strategy.address, { from: defiops });

            //------
            await vaultSavings.registerVault(_vaultProtocol.address, _poolToken.address, { from: owner });

            return _vaultProtocol;
        }

        afterEach(async() => await globalSnap.revert());

        it('The addresses of registered tokens are correct', async() => {
            const vaultOneToken = await VaultProtocol.new({ from: owner });
            await (<any>vaultOneToken).methods['initialize(address,address[])'](
                pool.address, [dai.address], { from: owner });
            const supportedTokensOne = await (<any>vaultOneToken).supportedTokens({ from: owner });

            const vaultTwoTokens = await VaultProtocol.new({ from: owner });
            await (<any>vaultTwoTokens).methods['initialize(address,address[])'](
                pool.address, [dai.address, usdc.address], { from: owner });
            const supportedTokensTwo = await (<any>vaultTwoTokens).supportedTokens({ from: owner });

            const vaultManyTokens = await VaultProtocol.new({ from: owner });
            await (<any>vaultManyTokens).methods['initialize(address,address[])'](
                pool.address, [dai.address, usdc.address, usdt.address, busd.address], { from: owner });
            const supportedTokensMany = await (<any>vaultManyTokens).supportedTokens({ from: owner });

            expect(supportedTokensOne).to.eql([dai.address]);
            expect(supportedTokensTwo).to.eql([dai.address, usdc.address]);
            expect(supportedTokensMany).to.eql([dai.address, usdc.address, usdt.address, busd.address]);
        });

        it('The number of registered tokens is correct', async() => {
            const vaultOneToken = await VaultProtocol.new({ from: owner });
            await (<any>vaultOneToken).methods['initialize(address,address[])'](
                pool.address, [dai.address], { from: owner });
            const supportedTokensCountOne = await (<any>vaultOneToken).supportedTokensCount({ from: owner });

            const vaultTwoTokens = await VaultProtocol.new({ from: owner });
            await (<any>vaultTwoTokens).methods['initialize(address,address[])'](
                pool.address, [dai.address, usdc.address], { from: owner });
            const supportedTokensCountTwo = await (<any>vaultTwoTokens).supportedTokensCount({ from: owner });

            const vaultManyTokens = await VaultProtocol.new({ from: owner });
            await (<any>vaultManyTokens).methods['initialize(address,address[])'](
                pool.address, [dai.address, usdc.address, usdt.address, busd.address], { from: owner });
            const supportedTokensCountMany = await (<any>vaultManyTokens).supportedTokensCount({ from: owner });

            expect(supportedTokensCountOne.toNumber()).to.equal(1);
            expect(supportedTokensCountTwo.toNumber()).to.equal(2);
            expect(supportedTokensCountMany.toNumber()).to.equal(4);
        });

        it('Cannot deposit a token that wasn\'t registered (one registered)', async() => {
            const tokens = [dai.address];
            const vaultOneToken = await vaultSetup(tokens);

            await usdc.approve(vaultOneToken.address, 50, { from: user1 });
            await expectRevert(
                (<any>vaultOneToken).methods['depositToVault(address,address,uint256)'](
                    user1, usdc.address, 50, { from: defiops }),
                'Token is not registered in the vault'
            );
        });

        it('Cannot deposit a token that wasn\'t registered (many registered)', async() => {
            const vaultTwoTokens = await vaultSetup([dai.address, busd.address]);

            await busd.approve(vaultTwoTokens.address, 50, { from: user1 });
            await usdc.approve(vaultTwoTokens.address, 30, { from: user1 });
            await expectRevert(
                (<any>vaultTwoTokens).methods['depositToVault(address,address[],uint256[])'](
                    user1, [busd.address, usdc.address], [50, 30], { from: defiops }),
                'Token is not registered in the vault'
            );

            const vaultManyTokens = await vaultSetup([usdt.address, busd.address, usdc.address]);

            await dai.approve(vaultManyTokens.address, 10, { from: user1 });
            await busd.approve(vaultManyTokens.address, 20, { from: user1 });
            await usdc.approve(vaultManyTokens.address, 30, { from: user1 });
            await usdt.approve(vaultManyTokens.address, 40, { from: user1 });

            await expectRevert(
                (<any>vaultManyTokens).methods['depositToVault(address,address[],uint256[])'](
                    user1, [dai.address], [10], { from: defiops }),
                'Token is not registered in the vault'
            );
        });

        it('Cannot withdraw a token that wasn\'t registered (one registered)', async() => {
            const tokens = [dai.address];
            const vaultOneToken = await vaultSetup(tokens);

            await expectRevert(
                (<any>vaultOneToken).methods['withdrawFromVault(address,address,uint256)'](
                    user1, usdc.address, 100, { from: defiops }),
                'Token is not registered in the vault'
            );
        });

        it('Cannot withdraw a token that wasn\'t registered (many registered)', async() => {
            const vaultTwoTokens = await vaultSetup([dai.address, busd.address]);
            const vaultManyTokens = await vaultSetup([usdt.address, busd.address, usdc.address]);

            await expectRevert(
                (<any>vaultTwoTokens).methods['withdrawFromVault(address,address[],uint256[])'](
                    user1, [busd.address, usdc.address], [50, 30], { from: defiops }),
                'Token is not registered in the vault'
            );
            await expectRevert(
                (<any>vaultManyTokens).methods['withdrawFromVault(address,address[],uint256[])'](
                    user1, [dai.address], [10], { from: defiops }),
                'Token is not registered in the vault'
            );
        });
    });

    describe('Identifier of a strategy', async() => {

        it('A strategy identifier should be correct', async() => {
            let _strategy = await VaultStrategy.new({ from: owner });
            await (<any>_strategy).methods['initialize(string)']('123', { from: owner });
            let strategyId = await _strategy.getStrategyId({ from: owner });
            expect(strategyId).to.equal('123');

            _strategy = await VaultStrategy.new({ from: owner });
            await (<any>_strategy).methods['initialize(string)']('2384358972357', { from: owner });
            strategyId = await _strategy.getStrategyId({ from: owner });
            expect(strategyId).to.equal('2384358972357');
        });

    });

    describe('Storage clearing', async() => {
        let snap: Snapshot;
        before(async() => {
            await dai.approve(strategy.address, 1000, { from: protocolStub });
            await dai.transfer(protocolStub, 180, { from: owner });

            snap = await Snapshot.create(web3.currentProvider);
        });

        after(async() => await globalSnap.revert());

        afterEach(async() => await snap.revert());

        it('Cannot clear deposits storage with active deposit', async() => {
            await dai.transfer(vaultProtocol.address, 80, { from: user1 });
            await poolToken.mint(user1, 80, { from: defiops });

            await vaultProtocol.methods['depositToVault(address,address[],uint256[])'](user1,
                [dai.address], [80], { from: defiops });

            await expectRevert(vaultProtocol.clearOnHoldDeposits({ from: defiops }),
                'There are unprocessed deposits'
            );
        });

        it('Cannot clear requests storage with active request', async() => {
            await vaultProtocol.methods['withdrawFromVault(address,address[],uint256[])'](
                user1, [dai.address], [80], { from: defiops });

            await expectRevert(vaultProtocol.clearWithdrawRequests({ from: defiops }),
                'There are unprocessed requests'
            );
        });

        it('Clear deposits storage with resolved deposits', async() => {
            await dai.transfer(vaultProtocol.address, 80, { from: user1 });
            await poolToken.mint(user1, 80, { from: defiops });

            await vaultProtocol.methods['depositToVault(address,address[],uint256[])'](user1,
                [dai.address], [80], { from: defiops });

            await vaultProtocol.operatorAction(strategy.address, { from: defiops });

            const res = await vaultProtocol.clearOnHoldDeposits({ from: defiops });
            expectEvent(res, 'DepositsCleared', {_vault: vaultProtocol.address});
            
        });

        it('Clear requests storage with resolved requests', async() => {
            await vaultProtocol.methods['withdrawFromVault(address,address[],uint256[])'](
                user1, [dai.address], [80], { from: defiops });

            await vaultProtocol.operatorAction(strategy.address, { from: defiops });

            const res = await vaultProtocol.clearWithdrawRequests({ from: defiops });
            expectEvent(res, 'RequestsCleared', {_vault: vaultProtocol.address});
        });
    });

});
