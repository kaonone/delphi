const { expectEvent } = require('@openzeppelin/test-helpers');
import { expect } from 'chai';

import {
    VaultProtocolOneCoinInstance,
    VaultPoolTokenInstance,
    PoolInstance,
    TestErc20Instance,
    VaultSavingsModuleInstance,
    VaultStrategyStubInstance
} from '../../../types/truffle-contracts/index';
import Snapshot from '../../utils/snapshot';
const expectRevert = require('../../utils/expectRevert');

const ERC20 = artifacts.require('TestERC20');
const Pool = artifacts.require('Pool');
const VaultSavings = artifacts.require('VaultSavingsModule');
const VaultProtocol = artifacts.require('VaultProtocolOneCoin');
const VaultStrategy = artifacts.require('VaultStrategyStub');
const PoolToken = artifacts.require('VaultPoolToken');

contract('VaultProtocol: one coin', async([ owner, user1, user2, user3, defiops, protocolStub ]) => {

    let globalSnap: Snapshot;
    let vault: VaultProtocolOneCoinInstance;
    let dai: TestErc20Instance;
    let usdc: TestErc20Instance;
    let poolToken: VaultPoolTokenInstance;
    let pool: PoolInstance;
    let vaultSavings: VaultSavingsModuleInstance;
    let strategy: VaultStrategyStubInstance;

    before(async() => {
        // Deposit token 1
        dai = await ERC20.new({ from: owner });
        await (<TestErc20Instance> dai).methods['initialize(string,string,uint8)']('DAI', 'DAI', 18, { from: owner });
        // Deposit token 2
        usdc = await ERC20.new({ from: owner });
        await (<TestErc20Instance> usdc)
            .methods['initialize(string,string,uint8)']('USDC', 'USDC', 18, { from: owner });

        await dai.transfer(user1, 1000, { from: owner });
        await dai.transfer(user2, 1000, { from: owner });
        await dai.transfer(user3, 1000, { from: owner });

        await usdc.transfer(user1, 1000, { from: owner });
        await usdc.transfer(user2, 1000, { from: owner });
        await usdc.transfer(user3, 1000, { from: owner });

        //------
        pool = await Pool.new({ from: owner });
        await (<PoolInstance> pool).methods['initialize()']({ from: owner });
        //------
        vaultSavings = await VaultSavings.new({ from: owner });
        await (<VaultSavingsModuleInstance> vaultSavings).methods['initialize(address)'](pool.address, { from: owner });
        await vaultSavings.addVaultOperator(defiops, { from: owner });

        await pool.set('vault', vaultSavings.address, true, { from: owner });
        //------
        vault = await VaultProtocol.new({ from: owner });
        await (<VaultProtocolOneCoinInstance> vault).methods['initialize(address,address[])'](
            pool.address, [dai.address], { from: owner });
        await vault.addDefiOperator(defiops, { from: owner });
        //------
        poolToken = await PoolToken.new({ from: owner });
        await (<VaultPoolTokenInstance> poolToken).methods['initialize(address,string,string)'](
            pool.address, 'VaultSavings', 'VLT', { from: owner });

        await poolToken.addMinter(vaultSavings.address, { from: owner });
        await poolToken.addMinter(vault.address, { from: owner });
        await poolToken.addMinter(defiops, { from: owner });
        //------
        strategy = await VaultStrategy.new({ from: owner });
        await (<VaultStrategyStubInstance> strategy).methods['initialize(string)']('1', { from: owner });
        await strategy.setProtocol(protocolStub, { from: owner });

        await strategy.addDefiOperator(defiops, { from: owner });
        await strategy.addDefiOperator(vault.address, { from: owner });
        //------
        await vault.registerStrategy(strategy.address, { from: defiops });
        await vault.setQuickWithdrawStrategy(strategy.address, { from: defiops });
        await vault.setAvailableEnabled(true, { from: owner });

        //------
        await vaultSavings.registerVault(vault.address, poolToken.address, { from: owner });

        globalSnap = await Snapshot.create(web3.currentProvider);
    });

    describe('Deposit into the vault', () => {

        afterEach(async() => await globalSnap.revert());

        it('Deposit single token into the vault', async() => {
            const before = {
                userBalance: await dai.balanceOf(user1),
                vaultBalance: await dai.balanceOf(vault.address)
            };

            let onhold = await vault.amountOnHold(user1, dai.address);
            expect(onhold.toNumber(), 'Deposit is not empty').to.equal(0);

            await dai.transfer(vault.address, 10, { from: user1 });
            const depositResult = await (<VaultProtocolOneCoinInstance> vault)
                .methods['depositToVault(address,address,uint256)'](user1, dai.address, 10, { from: defiops });

            expectEvent(depositResult, 'DepositToVault', { _user: user1, _token: dai.address, _amount: '10' });

            onhold = await vault.amountOnHold(user1, dai.address);
            expect(onhold.toNumber(), 'Deposit was not set on-hold').to.equal(10);

            const after = {
                userBalance: await dai.balanceOf(user1),
                vaultBalance: await dai.balanceOf(vault.address)
            };
            expect(after.vaultBalance.sub(before.vaultBalance).toNumber(), 'Tokens are not transferred to vault')
                .to.equal(10);
            expect(before.userBalance.sub(after.userBalance).toNumber(), 'Tokens are not transferred from user')
                .to.equal(10);
        });

        it('Impossible to deposit in unregistered token (deposit one token)', async() => {
            await usdc.transfer(vault.address, 10, { from: user1 });
            await expectRevert(
                (<VaultProtocolOneCoinInstance> vault).methods['depositToVault(address,address,uint256)'](
                    user1, usdc.address, 10, { from: defiops }),
                'Token is not registered'
            );
        });

        it('Impossible to deposit in unregistered token (deposit many tokens)', async() => {
            let onhold = await vault.amountOnHold(user1, dai.address);
            expect(onhold.toNumber(), 'Deposit is not empty').to.equal(0);

            await dai.transfer(vault.address, 10, { from: user1 });
            await usdc.transfer(vault.address, 5, { from: user1 });

            await expectRevert(
                (<VaultProtocolOneCoinInstance>vault).methods['depositToVault(address,address[],uint256[])'](
                    user1, [dai.address, usdc.address], [10, 5], { from: defiops }),
                'Token is not registered in the vault'
            );

            onhold = await vault.amountOnHold(user1, dai.address);
            expect(onhold.toNumber(), 'Deposit should not be set on-hold').to.equal(0);
        });

        it('Deposit from several users to the vault', async() => {
            const before = { vaultBalance: await dai.balanceOf(vault.address) };

            await dai.transfer(vault.address, 10, { from: user1 });
            await (<VaultProtocolOneCoinInstance> vault).methods['depositToVault(address,address,uint256)'](
                user1, dai.address, 10, { from: defiops });
            await dai.transfer(vault.address, 20, { from: user2 });
            await (<VaultProtocolOneCoinInstance> vault).methods['depositToVault(address,address,uint256)'](
                user2, dai.address, 20, { from: defiops });

            let onhold = await vault.amountOnHold(user1, dai.address);
            expect(onhold.toNumber(), 'Deposit (1) was not added to on-hold').to.equal(10);

            onhold = await vault.amountOnHold(user2, dai.address);
            expect(onhold.toNumber(), 'Deposit (2) was not added to on-hold').to.equal(20);

            const after = { vaultBalance: await dai.balanceOf(vault.address) };
            expect(after.vaultBalance.sub(before.vaultBalance).toNumber(), 'Tokens are not transferred to vault')
                .to.equal(30);
        });

        it('Additional deposit', async() => {
            const before = {
                userBalance: await dai.balanceOf(user1),
                vaultBalance: await dai.balanceOf(vault.address)
            };

            await dai.transfer(vault.address, 30, { from: user1 });

            let depositResult = await (<VaultProtocolOneCoinInstance> vault)
                .methods['depositToVault(address,address,uint256)'](user1, dai.address, 10, { from: defiops });
            expectEvent(depositResult, 'DepositToVault', { _user: user1, _token: dai.address, _amount: '10' });

            depositResult = await (<VaultProtocolOneCoinInstance> vault)
                .methods['depositToVault(address,address,uint256)'](user1, dai.address, 20, { from: defiops });
            expectEvent(depositResult, 'DepositToVault', { _user: user1, _token: dai.address, _amount: '20' });

            const onhold = await vault.amountOnHold(user1, dai.address);
            expect(onhold.toNumber(), 'Deposit was not added to on-hold').to.equal(30);

            const after = {
                userBalance: await dai.balanceOf(user1),
                vaultBalance: await dai.balanceOf(vault.address)
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
            await dai.transfer(vault.address, 100, { from: owner });
            await dai.transfer(vault.address, 100, { from: user1 });

            await (<VaultProtocolOneCoinInstance> vault).methods['depositToVault(address,address[],uint256[])'](
                user1, [dai.address], [100], { from: defiops });

            snap = await Snapshot.create(web3.currentProvider);
        });

        after(async() => await globalSnap.revert());

        afterEach(async() => await snap.revert());

        it('Withdraw tokens from vault (enough liquidity)', async() => {
            const before = {
                userBalance: await dai.balanceOf(user1),
                vaultBalance: await dai.balanceOf(vault.address)
            };

            const withdrawResult = await (<VaultProtocolOneCoinInstance> vault)
                .methods['withdrawFromVault(address,address,uint256)'](user1, dai.address, 100, { from: defiops });

            expectEvent(withdrawResult, 'WithdrawFromVault', { _user: user1, _token: dai.address, _amount: '100' });
            expectEvent.notEmitted(withdrawResult, 'WithdrawRequestCreated');

            // Deposit record is removed from on-hold storage
            const onhold = await vault.amountOnHold(user1, dai.address);
            expect(onhold.toNumber(), 'On-hold deposit was not withdrawn').to.equal(0);

            const after = {
                userBalance: await dai.balanceOf(user1),
                vaultBalance: await dai.balanceOf(vault.address)
            };

            // Token is transfered back to the user
            expect(before.vaultBalance.sub(after.vaultBalance).toNumber(), 'Tokens are not transferred from vault')
                .to.equal(100);
            expect(after.userBalance.sub(before.userBalance).toNumber(), 'Tokens are not transferred to user')
                .to.equal(100);
        });

        it('Impossible to withdraw an unregistered token', async() => {
            // Only one token
            await usdc.transfer(vault.address, 1, { from: user1 });
            await expectRevert(
                (<VaultProtocolOneCoinInstance> vault)
                    .methods['withdrawFromVault(address,address,uint256)'](user1, usdc.address, 1, { from: defiops }),
                'Token is not registered in the vault'
            );

            // Multiple tokens
            const before = {
                userBalance: await dai.balanceOf(user1),
                vaultBalance: await dai.balanceOf(vault.address)
            };
            await expectRevert(
                (<VaultProtocolOneCoinInstance>vault).methods['withdrawFromVault(address,address[],uint256[])'](
                    user1, [dai.address, usdc.address], [100, 1], { from: defiops }),
                'Token is not registered in the vault'
            );

            const onhold = await vault.amountOnHold(user1, dai.address);
            expect(onhold.toNumber(), 'On-hold deposit was withdrawn').to.equal(100);

            const after = {
                userBalance: await dai.balanceOf(user1),
                vaultBalance: await dai.balanceOf(vault.address)
            };

            // Token is transfered back to the user
            expect(before.vaultBalance.toNumber(), 'Tokens should not be transferred from vault')
                .to.equal(after.vaultBalance.toNumber());
            expect(after.userBalance.toNumber(), 'Tokens should not be transferred to user')
                .to.equal(before.userBalance.toNumber());
        });

        it('Withdraw more tokens than deposited on-hold (enough liquidity)', async() => {
            const before = {
                userBalance: await dai.balanceOf(user1),
                vaultBalance: await dai.balanceOf(vault.address)
            };

            const withdrawResult = await (<VaultProtocolOneCoinInstance> vault)
                .methods['withdrawFromVault(address,address,uint256)'](user1, dai.address, 150, { from: defiops });

            expectEvent(withdrawResult, 'WithdrawFromVault', { _user: user1, _token: dai.address, _amount: '150' });
            expectEvent.notEmitted(withdrawResult, 'WithdrawRequestCreated');

            // Deposit record is removed from on-hold storage
            const onholdAfter = await vault.amountOnHold(user1, dai.address);
            expect(onholdAfter.toNumber(), 'On-hold deposit was not withdrawn').to.equal(0);

            const after = {
                userBalance: await dai.balanceOf(user1),
                vaultBalance: await dai.balanceOf(vault.address)
            };

            // Token is transfered back to the user
            expect(before.vaultBalance.sub(after.vaultBalance).toNumber(), 'Tokens are not transferred from vault')
                .to.equal(150);
            expect(after.userBalance.sub(before.userBalance).toNumber(), 'Tokens are not transferred to user')
                .to.equal(150);
        });

        it('Withdraw the part of on-hold tokens (enough liquidity)', async() => {
            const before = {
                userBalance: await dai.balanceOf(user1),
                vaultBalance: await dai.balanceOf(vault.address)
            };

            const onholdBefore = await vault.amountOnHold(user1, dai.address);
            const withdrawResult = await (<VaultProtocolOneCoinInstance> vault)
                .methods['withdrawFromVault(address,address,uint256)'](user1, dai.address, 50, { from: defiops });

            expectEvent(withdrawResult, 'WithdrawFromVault', { _user: user1, _token: dai.address, _amount: '50' });
            expectEvent.notEmitted(withdrawResult, 'WithdrawRequestCreated');

            // Deposit record is updated in the on-hold storage
            const onholdAfter = await vault.amountOnHold(user1, dai.address);
            expect(onholdBefore.sub(onholdAfter).toNumber(), 'On-hold deposit was not withdrawn').to.equal(50);

            const after = {
                userBalance: await dai.balanceOf(user1),
                vaultBalance: await dai.balanceOf(vault.address)
            };

            // Token is transfered back to the user
            expect(before.vaultBalance.sub(after.vaultBalance).toNumber(), 'Tokens are not transferred from vault')
                .to.equal(50);
            expect(after.userBalance.sub(before.userBalance).toNumber(), 'Tokens are not transferred to user')
                .to.equal(50);
        });

        it('Withdraw if no on-hold tokens (enough liquidity)', async() => {
            const before = {
                userBalance: await dai.balanceOf(user2),
                vaultBalance: await dai.balanceOf(vault.address)
            };

            const withdrawResult = await (<VaultProtocolOneCoinInstance> vault)
                .methods['withdrawFromVault(address,address,uint256)'](user2, dai.address, 100, { from: defiops });

            expectEvent(withdrawResult, 'WithdrawFromVault', { _user: user2, _token: dai.address, _amount: '100' });
            expectEvent.notEmitted(withdrawResult, 'WithdrawRequestCreated');

            const onhold = await vault.amountOnHold(user2, dai.address);
            expect(onhold.toNumber(), 'On-hold deposit was not withdrawn').to.equal(0);

            const after = {
                userBalance: await dai.balanceOf(user2),
                vaultBalance: await dai.balanceOf(vault.address)
            };

            // Token is transfered to the user
            expect(before.vaultBalance.sub(after.vaultBalance).toNumber(), 'Tokens are not transferred from vault')
                .to.equal(100);
            expect(after.userBalance.sub(before.userBalance).toNumber(), 'Tokens are not transferred to user')
                .to.equal(100);
        });

    });

    describe('Create withdrawal request', () => {

        let snap: Snapshot;

        before(async() => {
            await dai.transfer(vault.address, 100, { from: user1 });
            await (<VaultProtocolOneCoinInstance> vault).methods['depositToVault(address,address[],uint256[])'](
                user1, [dai.address], [100], { from: defiops });

            snap = await Snapshot.create(web3.currentProvider);
        });

        after(async() => await globalSnap.revert());

        afterEach(async() => await snap.revert());

        it('Withdraw token (no on-hold tokens, not enough liquidity)', async() => {
            // Liquidity is withdrawn by another user
            await (<VaultProtocolOneCoinInstance> vault).methods['withdrawFromVault(address,address,uint256)'](
                user3, dai.address, 100, { from: defiops });

            const before = {
                userBalance: await dai.balanceOf(user2),
                vaultBalance: await dai.balanceOf(vault.address)
            };

            // User2 tries to withdraw more tokens than are currently on the protocol
            const withdrawResult = await (<VaultProtocolOneCoinInstance> vault)
                .methods['withdrawFromVault(address,address,uint256)'](user2, dai.address, 100, { from: defiops });

            expectEvent(
                withdrawResult, 'WithdrawRequestCreated', { _user: user2, _token: dai.address, _amount: '100' }
            );
            expectEvent.notEmitted(withdrawResult, 'WithdrawFromVault');

            const after = {
                userBalance: await dai.balanceOf(user2),
                vaultBalance: await dai.balanceOf(vault.address)
            };

            // Token is not transferred to the user
            expect(before.vaultBalance.toNumber(), 'Tokens should not be transferred from protocol')
                .to.equal(after.vaultBalance.toNumber());
            expect(after.userBalance.toNumber(), 'Tokens should not be transferred to user')
                .to.equal(before.userBalance.toNumber());

            // User has withdraw request created
            const requestedAmount = await vault.amountRequested(user2, dai.address);
            expect(requestedAmount.toNumber(), 'Request should be created').to.equal(100);
        });

        it('Withdraw with on-hold token (not enough liquidity)', async() => {
            const onholdBefore = await vault.amountOnHold(user1, dai.address);

            // Liquidity is withdrawn by another user
            await (<VaultProtocolOneCoinInstance> vault).methods['withdrawFromVault(address,address,uint256)'](
                user2, dai.address, 100, { from: defiops });

            const before = {
                userBalance: await dai.balanceOf(user1),
                vaultBalance: await dai.balanceOf(vault.address)
            };

            // User1 (with on-hold tokens) tries to withdraw more tokens than are currently on the protocol
            const withdrawResult = await (<VaultProtocolOneCoinInstance> vault)
                .methods['withdrawFromVault(address,address,uint256)'](user1, dai.address, 100, { from: defiops });

            expectEvent(
                withdrawResult, 'WithdrawRequestCreated', { _user: user1, _token: dai.address, _amount: '100' }
            );
            expectEvent.notEmitted(withdrawResult, 'WithdrawFromVault');

            const onholdAfter = await vault.amountOnHold(user1, dai.address);

            expect(onholdAfter.toNumber(), 'On-hold deposit should be left untouched')
                .to.equal(onholdBefore.toNumber());

            const after = {
                userBalance: await dai.balanceOf(user1),
                vaultBalance: await dai.balanceOf(vault.address)
            };

            // Token is not transferred to the user
            expect(before.vaultBalance.toNumber(), 'Tokens should not be transferred from protocol')
                .to.equal(after.vaultBalance.toNumber());
            expect(after.userBalance.toNumber(), 'Tokens should not be transferred to user')
                .to.equal(before.userBalance.toNumber());

            // Withdraw request created
            const requestedAmount = await vault.amountRequested(user1, dai.address);
            expect(requestedAmount.toNumber(), 'Request should be created').to.equal(100);

        });

    });

    describe('Operator resolves withdraw requests', () => {

        let snap: Snapshot;

        before(async() => {
            await dai.transfer(protocolStub, 1000, { from: owner });
            await dai.approve(strategy.address, 1000, { from: protocolStub });

            snap = await Snapshot.create(web3.currentProvider);
        });

        after(async() => await globalSnap.revert());

        afterEach(async() => await snap.revert());

        it('On-hold funds are sent to the protocol', async() => {
            const before = {
                userBalance: await dai.balanceOf(user1),
                vaultBalance: await dai.balanceOf(vault.address),
                protocolBalance: await dai.balanceOf(protocolStub),
            };

            // Imitate LP tokens minting
            await poolToken.mint(user1, 100, { from: defiops });

            await dai.transfer(vault.address, 100, { from: user1 });
            await (<VaultProtocolOneCoinInstance> vault).methods['depositToVault(address,address,uint256)'](
                user1, dai.address, 100, { from: defiops });

            // Withdraw by operator
            const opResult = await vault.operatorAction(strategy.address, { from: defiops });
            expectEvent(opResult, 'DepositByOperator', { _amount: '100' });

            await vault.clearWithdrawRequests({ from: defiops });
            await vault.clearOnHoldDeposits({ from: defiops });

            const onhold = await vault.amountOnHold(user1, dai.address);
            expect(onhold.toNumber(), 'On-hold record should be deleted').to.equal(0);

            const after = {
                userBalance: await dai.balanceOf(user1),
                vaultBalance: await dai.balanceOf(vault.address),
                protocolBalance: await dai.balanceOf(protocolStub),
            };

            expect(after.vaultBalance.toNumber(), 'Tokens are not transferred from vault').to.equal(0);

            expect(after.protocolBalance.sub(before.protocolBalance).toNumber(),
                'Protocol didn\'t receive tokens').to.equal(100);
        });

        it('Withdraw request is resolved from current liquidity', async() => {
            const before = {
                userBalance: await dai.balanceOf(user1),
                vaultBalance: await dai.balanceOf(vault.address),
                protocolBalance: await dai.balanceOf(protocolStub),
            };

            // Withdrawal requests created
            await (<VaultProtocolOneCoinInstance> vault).methods['withdrawFromVault(address,address,uint256)'](
                user1, dai.address, 100, { from: defiops });

            // Imitate LP tokens minting
            await poolToken.mint(user2, 100, { from: defiops });

            // Deposits to create the exact liquidity
            await dai.transfer(vault.address, 100, { from: user2 });
            await (<VaultProtocolOneCoinInstance> vault).methods['depositToVault(address,address,uint256)'](
                user2, dai.address, 100, { from: defiops });

            // Withdraw by operator
            const opResult = await vault.operatorAction(strategy.address, { from: defiops });

            await vault.clearWithdrawRequests({ from: defiops });
            await vault.clearOnHoldDeposits({ from: defiops });

            expectEvent.notEmitted(opResult, 'WithdrawByOperator');
            expectEvent(opResult, 'WithdrawRequestsResolved');

            // Withdrawal requests are resolved
            const requested = await vault.amountRequested(user1, dai.address);
            expect(requested.toNumber(), 'Withdraw request should be resolved').to.equal(0);

            const after = {
                userBalance: await dai.balanceOf(user1),
                vaultBalance: await dai.balanceOf(vault.address),
                protocolBalance: await dai.balanceOf(protocolStub),
            };

            // Tokens to claim
            const claimable = await vault.claimableAmount(user1, dai.address);
            expect(claimable.toNumber(), 'Cannot claim tokens').to.equal(100);

            expect(after.vaultBalance.toNumber(), 'No new tokens should be transferred to vault').to.equal(100);
            expect(before.protocolBalance.sub(after.protocolBalance).toNumber(),
                'Protocol should not send tokens').to.equal(0);
        });

        it('Withdraw request is resolved with return from protocol', async() => {
            const before = {
                userBalance: await dai.balanceOf(user1),
                vaultBalance: await dai.balanceOf(vault.address),
                protocolBalance: await dai.balanceOf(protocolStub),
            };
            // Withdrawal requests created
            await (<VaultProtocolOneCoinInstance> vault).methods['withdrawFromVault(address,address,uint256)'](
                user1, dai.address, 100, { from: defiops });

            // Withdraw by operator
            const opResult = await vault.operatorAction(strategy.address, { from: defiops });

            await vault.clearWithdrawRequests({ from: defiops });
            await vault.clearOnHoldDeposits({ from: defiops });

            expectEvent.notEmitted(opResult, 'DepositByOperator');
            expectEvent(opResult, 'WithdrawRequestsResolved');
            expectEvent(opResult, 'WithdrawByOperator', { _amount: '100' });

            // Withdrawal requests are resolved
            const requested = await vault.amountRequested(user1, dai.address);
            expect(requested.toNumber(), 'Withdraw request should be resolved').to.equal(0);

            const after = {
                userBalance: await dai.balanceOf(user1),
                vaultBalance: await dai.balanceOf(vault.address),
                protocolBalance: await dai.balanceOf(protocolStub),
            };

            // Tokens to claim
            const claimable = await vault.claimableAmount(user1, dai.address);
            expect(claimable.toNumber(), 'Cannot claim tokens').to.equal(100);

            expect(after.vaultBalance.toNumber(), 'Tokens are not transferred to vault').to.equal(100);
            expect(before.protocolBalance.sub(after.protocolBalance).toNumber(), 'Protocol didn\'t send tokens')
                .to.equal(100);
        });

        it('Withdraw request is resolved for user with both on-hold and deposited amounts', async() => {
            // In case if there is not enough liquidity to fullfill the request - on-hold amount is left untouched
            // Withdrawal should not be fullfilled particulary

            // Create on-hold record
            await dai.transfer(vault.address, 100, { from: user1 });
            await (<VaultProtocolOneCoinInstance> vault).methods['depositToVault(address,address,uint256)'](
                user1, dai.address, 100, { from: defiops });

            const before = {
                userBalance: await dai.balanceOf(user1),
                vaultBalance: await dai.balanceOf(vault.address),
                protocolBalance: await dai.balanceOf(protocolStub),
            };

            // Withdrawal requests created
            await (<VaultProtocolOneCoinInstance> vault).methods['withdrawFromVault(address,address,uint256)'](
                user1, dai.address, 150, { from: defiops });

            // Withdraw by operator
            const opResult = await vault.operatorAction(strategy.address, { from: defiops });

            await vault.clearWithdrawRequests({ from: defiops });
            await vault.clearOnHoldDeposits({ from: defiops });

            expectEvent(opResult, 'WithdrawRequestsResolved');
            // On-hold deposit is resolved into claimable
            expectEvent.notEmitted(opResult, 'DepositByOperator');
            // Part of amount is withdrawn from the protocol - other taken from current liquidity
            expectEvent(opResult, 'WithdrawByOperator', { _amount: '50' });

            // Withdrawal request is resolved
            const requested = await vault.amountRequested(user1, dai.address);
            expect(requested.toNumber(), 'Withdraw request should be resolved').to.equal(0);

            // On-hold record is deleted during the request
            const onhold = await vault.amountOnHold(user1, dai.address);
            expect(onhold.toNumber(), 'On-hold record should be deleted').to.equal(0);

            // Total amount is marked as claimed
            const claimable = await vault.claimableAmount(user1, dai.address);
            expect(claimable.toNumber(), 'Cannot claim tokens').to.equal(150);

            const after = {
                userBalance: await dai.balanceOf(user1),
                vaultBalance: await dai.balanceOf(vault.address),
                protocolBalance: await dai.balanceOf(protocolStub),
            };

            // Since both deposit and withdraw are fullfilled, only (requested - on-hold) is sent from the protocol
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
            //Create some claimable amounts
            await dai.transfer(protocolStub, 180, { from: owner });

            await (<VaultProtocolOneCoinInstance> vault).methods['withdrawFromVault(address,address[],uint256[])'](
                user1, [dai.address], [100], { from: defiops });
            await (<VaultProtocolOneCoinInstance> vault).methods['withdrawFromVault(address,address,uint256)'](
                user2, dai.address, 80, { from: defiops });

            await vault.operatorAction(strategy.address, { from: defiops });
            await vault.clearWithdrawRequests({ from: defiops });
            await vault.clearOnHoldDeposits({ from: defiops });

            snap = await Snapshot.create(web3.currentProvider);
        });

        after(async() => await globalSnap.revert());

        afterEach(async() => await snap.revert());

        it('Deposit from user does not influence claimable amount', async() => {
            const claimableBefore = await vault.claimableAmount(user1, dai.address);
            const claimableTotalBefore = await vault.totalClaimableAmount(dai.address);

            await dai.transfer(vault.address, 150, { from: user1 });
            await (<VaultProtocolOneCoinInstance> vault).methods['depositToVault(address,address,uint256)'](
                user1, dai.address, 150, { from: defiops });

            const claimableAfter = await vault.claimableAmount(user1, dai.address);
            const claimableTotalAfter = await vault.totalClaimableAmount(dai.address);

            expect(claimableBefore.toNumber(), 'Claimable tokens amount changed').to.equal(claimableAfter.toNumber());
            expect(claimableTotalBefore.toNumber(), 'Total claimable tokens amount changed')
                .to.equal(claimableTotalAfter.toNumber());
        });

        it('Withdraw by user (from liquidity on vault) does not influence claimable amount', async() => {
            // Create some liquidity in the vault
            await dai.transfer(vault.address, 200, { from: user3 });
            await (<VaultProtocolOneCoinInstance> vault).methods['depositToVault(address,address,uint256)'](
                user3, dai.address, 200, { from: defiops });

            const claimableBefore = await vault.claimableAmount(user1, dai.address);
            const claimableTotalBefore = await vault.totalClaimableAmount(dai.address);

            const opResult = await (<VaultProtocolOneCoinInstance> vault)
                .methods['withdrawFromVault(address,address,uint256)'](user1, dai.address, 100, { from: defiops });
            expectEvent.notEmitted(opResult, 'WithdrawRequestCreated');
            expectEvent(opResult, 'WithdrawFromVault', { _user: user1, _token: dai.address, _amount: '100' });

            const claimableAfter = await vault.claimableAmount(user1, dai.address);
            const claimableTotalAfter = await vault.totalClaimableAmount(dai.address);

            // Since withdrawal with enough liquidity is already tested, we need to check the claimable amount
            expect(claimableBefore.toNumber(), 'Claimable tokens amount changed').to.equal(claimableAfter.toNumber());
            expect(claimableTotalBefore.toNumber(), 'Total claimable tokens amount changed')
                .to.equal(claimableTotalAfter.toNumber());
        });

        it('Withdraw does not influence claimable amount, withdraw request is created', async() => {
            // There is not enough liquidity in the vault
            const claimableBefore = await vault.claimableAmount(user1, dai.address);
            const claimableTotalBefore = await vault.totalClaimableAmount(dai.address);

            const opResult = await (<VaultProtocolOneCoinInstance> vault)
                .methods['withdrawFromVault(address,address,uint256)'](user1, dai.address, 100, { from: defiops });
            expectEvent(opResult, 'WithdrawRequestCreated');

            const claimableAfter = await vault.claimableAmount(user1, dai.address);
            const claimableTotalAfter = await vault.totalClaimableAmount(dai.address);

            expect(claimableBefore.toNumber(), 'Claimable tokens amount changed').to.equal(claimableAfter.toNumber());
            expect(claimableTotalBefore.toNumber(), 'Total claimable tokens amount changed')
                .to.equal(claimableTotalAfter.toNumber());
        });

        it('Deposit by operator does not influence claimable tokens', async() => {
            // Create on-hold record to be resolved
            await dai.transfer(vault.address, 80, { from: user1 });
            await (<VaultProtocolOneCoinInstance> vault).methods['depositToVault(address,address,uint256)'](
                user1, dai.address, 80, { from: defiops });

            const claimableBefore = await vault.claimableAmount(user1, dai.address);
            const claimableTotalBefore = await vault.totalClaimableAmount(dai.address);

            const opResult = await vault.operatorAction(strategy.address, { from: defiops });
            await vault.clearWithdrawRequests({ from: defiops });
            await vault.clearOnHoldDeposits({ from: defiops });

            // On-hold tokens are deposited
            expectEvent(opResult, 'DepositByOperator');

            const claimableAfter = await vault.claimableAmount(user1, dai.address);
            const claimableTotalAfter = await vault.totalClaimableAmount(dai.address);

            expect(claimableBefore.toNumber(), 'Claimable tokens amount changed').to.equal(claimableAfter.toNumber());
            expect(claimableTotalBefore.toNumber(), 'Total claimable tokens amount changed')
                .to.equal(claimableTotalAfter.toNumber());
        });

        it('Withdraw request resolving increases claimable amount', async() => {
            await dai.transfer(protocolStub, 100, { from: owner });
            await (<VaultProtocolOneCoinInstance> vault).methods['withdrawFromVault(address,address,uint256)'](
                user1, dai.address, 100, { from: defiops });

            const claimableBefore = await vault.claimableAmount(user1, dai.address);
            const claimableTotalBefore = await vault.totalClaimableAmount(dai.address);

            const opResult = await vault.operatorAction(strategy.address, { from: defiops });
            await vault.clearWithdrawRequests({ from: defiops });
            await vault.clearOnHoldDeposits({ from: defiops });

            // Additional amount requested
            expectEvent(opResult, 'WithdrawByOperator');

            const claimableAfter = await vault.claimableAmount(user1, dai.address);
            const claimableTotalAfter = await vault.totalClaimableAmount(dai.address);

            // Increases by requested amount
            expect(claimableAfter.sub(claimableBefore).toNumber(), 'Claimable tokens amount not changed').to.equal(100);
            expect(claimableTotalAfter.sub(claimableTotalBefore).toNumber(),
                'Total claimable tokens amount not changed').to.equal(100);
        });

        it('User claims all available tokens', async() => {
            const before = {
                userBalance: await dai.balanceOf(user1),
                vaultBalance: await dai.balanceOf(vault.address),
                claimableTotal: await vault.totalClaimableAmount(dai.address),
            };

            await vault.claimRequested(user1, { from: user1 });

            const after = {
                userBalance: await dai.balanceOf(user1),
                vaultBalance: await dai.balanceOf(vault.address),
                claimable: await vault.claimableAmount(user1, dai.address),
                claimableTotal: await vault.totalClaimableAmount(dai.address),
            };

            expect(after.claimable.toNumber(), 'Not all tokens are claimed').to.equal(0);

            expect(after.userBalance.sub(before.userBalance).toNumber(), 'Tokens are not claimed to user')
                .to.equal(100);
            expect(before.vaultBalance.sub(after.vaultBalance).toNumber(), 'Tokens are not claimed from vault')
                .to.equal(100);
            expect(before.claimableTotal.sub(after.claimableTotal).toNumber(), 'Tokens total is not changed')
                .to.equal(100);
        });

        it('Claim by user does not influence other users claims', async() => {
            const claimableBefore = await vault.claimableAmount(user2, dai.address);
            const claimableTotalBefore = await vault.totalClaimableAmount(dai.address);

            await vault.claimRequested(user1, { from: user1 });

            const claimableAfter = await vault.claimableAmount(user2, dai.address);
            const claimableTotalAfter = await vault.totalClaimableAmount(dai.address);

            expect(claimableAfter.toNumber(), 'Claimable tokens amount should not be changed for other users')
                .to.equal(claimableBefore.toNumber());
            expect(claimableTotalBefore.sub(claimableTotalAfter).toNumber(),
                'Total claimable tokens amount not changed').to.equal(100);
        });

        it('Total claimable calculated correctly', async() => {
            // [50] - initial from before() + additional
            await dai.transfer(protocolStub, 50, { from: user1 });
            await (<VaultProtocolOneCoinInstance> vault).methods['withdrawFromVault(address,address,uint256)'](
                user1, dai.address, 50, { from: defiops });

            await vault.operatorAction(strategy.address, { from: defiops });
            await vault.clearWithdrawRequests({ from: defiops });
            await vault.clearOnHoldDeposits({ from: defiops });

            const claimable = await vault.totalClaimableAmount(dai.address);

            expect(claimable.toNumber(), 'Incorrect total claimable').to.equal(230);
        });

        it('Event generated after claim', async() => {
            await dai.transfer(protocolStub, 50, { from: user3 });
            await (<VaultProtocolOneCoinInstance> vault).methods['withdrawFromVault(address,address[],uint256[])'](
                user3, [dai.address], [50], { from: defiops });

            await vault.operatorAction(strategy.address, { from: defiops });

            const result = await vault.claimRequested(user3, { from: user1 });

            expectEvent(result, 'Claimed', { _vault: vault.address, _user: user3, _token: dai.address, _amount: '50' });
        });

    });

    describe('Quick withdraw', () => {

        let localSnap : Snapshot;

        before(async() => {
            await dai.approve(strategy.address, 1000, { from: protocolStub });
            await dai.transfer(protocolStub, 1000, { from: owner });

            localSnap = await Snapshot.create(web3.currentProvider);
        });

        after(async() => await globalSnap.revert());

        afterEach(async() => await localSnap.revert());

        it('Quick withdraw (has withdrawal request)', async() => {
            await vault.methods['withdrawFromVault(address,address[],uint256[])'](
                user1, [dai.address], [80], { from: owner });

            const before = {
                invault: await dai.balanceOf(vault.address),
                requested: await vault.amountRequested(user1, dai.address),
                instrategy: await dai.balanceOf(protocolStub),
                user: await dai.balanceOf(user1)
            };

            await vault.quickWithdraw(user1, [dai.address], [120], { from: defiops });

            const after = {
                invault: await dai.balanceOf(vault.address),
                requested: await vault.amountRequested(user1, dai.address),
                instrategy: await dai.balanceOf(protocolStub),
                user: await dai.balanceOf(user1)
            };

            // Check that Vault liquidity is unchanged
            expect(after.invault.sub(before.invault).toNumber(), 'Vault liquidity was changed').to.equal(0);
            // Check that request record is unchanged
            expect(after.requested.sub(before.requested).toNumber(), 'Requested amount was changed').to.equal(0);
            // Check that funds are withdraw from the strategy
            expect(after.instrategy.sub(before.instrategy).toNumber(), 'Strategy balance was not changed')
                .to.equal(-120);
            // Check that token is trasfered to the user
            expect(after.user.sub(before.user).toNumber(), 'User balance was not changed').to.equal(120);
        });

        it('Quick withdraw (enough liquidity)', async() => {
            const before = {
                invault: await dai.balanceOf(vault.address),
                instrategy: await dai.balanceOf(protocolStub),
                user: await dai.balanceOf(user1)
            };

            await vault.quickWithdraw(user1, [dai.address], [120], { from: defiops });

            const after = {
                invault: await dai.balanceOf(vault.address),
                instrategy: await dai.balanceOf(protocolStub),
                user: await dai.balanceOf(user1)
            };

            // Check that Vault liquidity is unchanged
            expect(after.invault.sub(before.invault).toNumber(), 'Vault liquidity was changed').to.equal(0);
            // Check that funds are withdraw from the strategy
            expect(after.instrategy.sub(before.instrategy).toNumber(), 'Strategy balance was not changed')
                .to.equal(-120);
            // Check that token is trasfered to the user
            expect(after.user.sub(before.user).toNumber(), 'User balance was not changed').to.equal(120);
        });

        it('Quick withdraw (has on-hold token, enough liquidity)', async() => {
            await vault.methods['depositToVault(address,address[],uint256[])'](user1,
                [dai.address], [140], { from: defiops });

            const before = {
                invault: await dai.balanceOf(vault.address),
                onhold: await vault.amountOnHold(user1, dai.address),
                instrategy: await dai.balanceOf(protocolStub),
                user: await dai.balanceOf(user1)
            };

            await vault.quickWithdraw(user1, [dai.address], [120], { from: defiops });

            const after = {
                invault: await dai.balanceOf(vault.address),
                onhold: await vault.amountOnHold(user1, dai.address),
                instrategy: await dai.balanceOf(protocolStub),
                user: await dai.balanceOf(user1)
            };

            // Check that Vault liquidity is unchanged
            expect(after.invault.sub(before.invault).toNumber(), 'Vault liquidity was changed').to.equal(0);
            // Check that on-hold record is unchanged
            expect(after.onhold.sub(before.onhold).toNumber(), 'On-hold amount was changed').to.equal(0);
            // Check that funds are withdraw from the strategy
            expect(after.instrategy.sub(before.instrategy).toNumber(), 'Strategy balance was not changed')
                .to.equal(-120);
            // Check that token is trasfered to the user
            expect(after.user.sub(before.user).toNumber(), 'User balance was not changed').to.equal(120);
        });

        it('Quick withdraw (has on-hold token, not enough liquidity)', async() => {
            await vault.methods['depositToVault(address,address[],uint256[])'](user1,
                [dai.address], [80], { from: defiops });

            const before = {
                invault: await dai.balanceOf(vault.address),
                onhold: await vault.amountOnHold(user1, dai.address),
                instrategy: await dai.balanceOf(protocolStub),
                user: await dai.balanceOf(user1)
            };

            await vault.quickWithdraw(user1, [dai.address], [120], { from: defiops });

            const after = {
                invault: await dai.balanceOf(vault.address),
                onhold: await vault.amountOnHold(user1, dai.address),
                instrategy: await dai.balanceOf(protocolStub),
                user: await dai.balanceOf(user1)
            };

            // Check that Vault liquidity is unchanged
            expect(after.invault.sub(before.invault).toNumber(), 'Vault liquidity was changed').to.equal(0);
            // Check that on-hold record is unchanged
            expect(after.onhold.sub(before.onhold).toNumber(), 'On-hold amount was changed').to.equal(0);
            // Check that funds are withdraw from the strategy
            expect(after.instrategy.sub(before.instrategy).toNumber(), 'Strategy balance was not changed')
                .to.equal(-120);
            // Check that token is trasfered to the user
            expect(after.user.sub(before.user).toNumber(), 'User balance was not changed').to.equal(120);
        });

        it('Quick withdraw (not enough liquidity)', async() => {
            const before = {
                invault: await dai.balanceOf(vault.address),
                instrategy: await dai.balanceOf(protocolStub),
                user: await dai.balanceOf(user1)
            };

            await vault.quickWithdraw(user1, [dai.address], [120], { from: defiops });

            const after = {
                invault: await dai.balanceOf(vault.address),
                instrategy: await dai.balanceOf(protocolStub),
                user: await dai.balanceOf(user1)
            };

            // Check that Vault liquidity is unchanged
            expect(after.invault.sub(before.invault).toNumber(), 'Vault liquidity was changed').to.equal(0);
            // Check that funds are withdraw from the strategy
            expect(after.instrategy.sub(before.instrategy).toNumber(), 'Strategy balance was not changed')
                .to.equal(-120);
            // Check that token is trasfered to the user
            expect(after.user.sub(before.user).toNumber(), 'User balance was not changed').to.equal(120);
        });

    });

    describe('Registered tokens only', () => {

        async function vaultSetup(tokens: Array<string>) {
            const _vault = await VaultProtocol.new({ from: owner });
            await (<VaultProtocolOneCoinInstance>_vault)
                .methods['initialize(address,address[])'](pool.address, tokens, { from: owner });
            await _vault.addDefiOperator(defiops, { from: owner });
            //------
            const _poolToken = await PoolToken.new({ from: owner });
            await (<VaultPoolTokenInstance>_poolToken).methods['initialize(address,string,string)'](
                pool.address, 'VaultSavings', 'VLT', { from: owner });

            await _poolToken.addMinter(vaultSavings.address, { from: owner });
            await _poolToken.addMinter(_vault.address, { from: owner });
            await _poolToken.addMinter(defiops, { from: owner });
            //------
            const _strategy = await VaultStrategy.new({ from: owner });
            await (<VaultStrategyStubInstance>_strategy).methods['initialize(string)']('1', { from: owner });
            await _strategy.setProtocol(protocolStub, { from: owner });

            await _strategy.addDefiOperator(defiops, { from: owner });
            await _strategy.addDefiOperator(_vault.address, { from: owner });
            //------
            await _vault.registerStrategy(_strategy.address, { from: defiops });

            //------
            await vaultSavings.registerVault(_vault.address, _poolToken.address, { from: owner });

            return _vault;
        }

        afterEach(async() => await globalSnap.revert());

        it('The addresses of registered tokens are correct', async() => {
            const _vault = await VaultProtocol.new({ from: owner });
            await (<VaultProtocolOneCoinInstance> _vault).methods['initialize(address,address[])'](
                pool.address, [dai.address], { from: owner });
            const supportedTokens = await (<VaultProtocolOneCoinInstance> _vault)
                .supportedTokens({ from: owner });

            expect(supportedTokens).to.eql([dai.address]);
        });

        it('The number of registered tokens is correct', async() => {
            const supportedTokensCountOne = await (<VaultProtocolOneCoinInstance> vault)
                .supportedTokensCount({ from: owner });
            expect(supportedTokensCountOne.toNumber()).to.equal(1);
        });

        it('Cannot deposit a token that wasn\'t registered', async() => {
            const tokens = [dai.address];
            const _vault = await vaultSetup(tokens);

            await usdc.approve(_vault.address, 50, { from: user1 });
            await expectRevert(
                (<VaultProtocolOneCoinInstance> _vault).methods['depositToVault(address,address,uint256)'](
                    user1, usdc.address, 50, { from: defiops }),
                'Token is not registered in the vault'
            );
        });

        it('Cannot withdraw a token that wasn\'t registered', async() => {
            const tokens = [dai.address];
            const _vault = await vaultSetup(tokens);

            await expectRevert(
                (<VaultProtocolOneCoinInstance> _vault).methods['withdrawFromVault(address,address,uint256)'](
                    user1, usdc.address, 100, { from: defiops }),
                'Token is not registered in the vault'
            );
        });

    });

    describe('Identifier of a strategy', async() => {

        it('A strategy identifier should be correct', async() => {
            let _strategy = await VaultStrategy.new({ from: owner });
            await (<VaultStrategyStubInstance> _strategy).methods['initialize(string)']('123', { from: owner });
            let strategyId = await _strategy.getStrategyId({ from: owner });
            expect(strategyId).to.equal('123');

            _strategy = await VaultStrategy.new({ from: owner });
            await (<VaultStrategyStubInstance> _strategy)
                .methods['initialize(string)']('2384358972357', { from: owner });
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
            await dai.transfer(vault.address, 80, { from: user1 });
            await poolToken.mint(user1, 80, { from: defiops });

            await vault.methods['depositToVault(address,address[],uint256[])'](user1,
                [dai.address], [80], { from: defiops });

            await expectRevert(vault.clearOnHoldDeposits({ from: defiops }),
                'There are unprocessed deposits'
            );
        });

        it('Cannot clear requests storage with active request', async() => {
            await vault.methods['withdrawFromVault(address,address[],uint256[])'](
                user1, [dai.address], [80], { from: defiops });

            await expectRevert(vault.clearWithdrawRequests({ from: defiops }),
                'There are unprocessed requests'
            );
        });

        it('Clear deposits storage with resolved deposits', async() => {
            await dai.transfer(vault.address, 80, { from: user1 });
            await poolToken.mint(user1, 80, { from: defiops });

            await vault.methods['depositToVault(address,address[],uint256[])'](user1,
                [dai.address], [80], { from: defiops });

            await vault.operatorAction(strategy.address, { from: defiops });

            const res = await vault.clearOnHoldDeposits({ from: defiops });
            expectEvent(res, 'DepositsCleared', { _vault: vault.address });
        });

        it('Clear requests storage with resolved requests', async() => {
            await vault.methods['withdrawFromVault(address,address[],uint256[])'](
                user1, [dai.address], [80], { from: defiops });

            await vault.operatorAction(strategy.address, { from: defiops });

            const res = await vault.clearWithdrawRequests({ from: defiops });
            expectEvent(res, 'RequestsCleared', { _vault: vault.address });
        });

    });

    describe('Full cycle', () => {

        let localSnap: Snapshot;

        before(async() => {
            await dai.approve(strategy.address, 5000, { from: protocolStub });
            localSnap = await Snapshot.create(web3.currentProvider);
        });

        after(async() => await globalSnap.revert());

        afterEach(async() => await localSnap.revert());

        it('All deposited funds plus yeild equal to all withdrawn funds', async() => {
            const sent = { user1: 15, user2: 20, user3: 50 };
            const vaultBalanceBefore = await dai.balanceOf(vault.address);
            const onHoldBefore = {
                user1: await vault.amountOnHold(user1, dai.address),
                user2: await vault.amountOnHold(user2, dai.address),
                user3: await vault.amountOnHold(user3, dai.address),
            };
            const balanceBefore = {
                user1: await dai.balanceOf(user1),
                user2: await dai.balanceOf(user2),
                user3: await dai.balanceOf(user3),
            };

            /**************************
             * 1. Users make deposits *
             *************************/
            // First deposits from 3 users
            // Deposits from user1
            await dai.transfer(vault.address, sent.user1, { from: user1 });
            await vault.methods['depositToVault(address,address[],uint256[])'](user1,
                [dai.address], [sent.user1], { from: defiops });
            // Send the same amount of pool tokens for user stablecoins
            await poolToken.mint(user1, sent.user1, { from: defiops });

            // Deposits from user2
            await dai.transfer(vault.address, sent.user2, { from: user2 });
            await vault.methods['depositToVault(address,address[],uint256[])'](user2,
                [dai.address], [sent.user2], { from: defiops });
            // Send the same amount of pool tokens for user stablecoins
            await poolToken.mint(user2, sent.user2, { from: defiops });

            // Deposits from user3
            await dai.transfer(vault.address, sent.user3, { from: user3 });
            await vault.methods['depositToVault(address,address[],uint256[])'](user3,
                [dai.address], [sent.user3], { from: defiops });
            // Send the same amount of pool tokens for user stablecoins
            await poolToken.mint(user3, sent.user3, { from: defiops });

            // Valut receives tokens
            const vaultBalanceAfter = await dai.balanceOf(vault.address);
            const onHoldAfter = {
                user1: await vault.amountOnHold(user1, dai.address),
                user2: await vault.amountOnHold(user2, dai.address),
                user3: await vault.amountOnHold(user3, dai.address),
            };
            const totalSent = sent.user1 + sent.user2 + sent.user3;

            expect(onHoldAfter.user1.sub(onHoldBefore.user1).toNumber(),
                'User1: on hold DAI amount should change').to.equal(sent.user1);

            expect(onHoldAfter.user2.sub(onHoldBefore.user2).toNumber(),
                'User2: on hold DAI amount should change').to.equal(sent.user2);

            expect(onHoldAfter.user3.sub(onHoldBefore.user3).toNumber(),
                'User3: on hold DAI amount should change').to.equal(sent.user3);

            expect(vaultBalanceAfter.sub(vaultBalanceBefore).toNumber(),
                'Vault: on hold DAI amount should change').to.equal(totalSent);

            // Operator resolves deposits to the strategy
            const stubBalanceBeforeAction = await dai.balanceOf(protocolStub);

            await vault.operatorAction(strategy.address, { from: defiops });

            const stubBalanceAfterAction = await dai.balanceOf(protocolStub);

            expect(stubBalanceAfterAction.sub(stubBalanceBeforeAction).toNumber(),
                'All DAI should be on the strategy').to.equal(totalSent);

            /*************************
             * 2. Yield is generated *
             ************************/
            // Add some yields to the protocol
            const yields = { dai: 10, usdc: 20, busd: 30, usdt: 40 };

            // Transfer yield
            await dai.transfer(protocolStub, yields.dai, { from: owner });

            // Hardcode profits for users
            const profits = { user1: 7, user2: 1, user3: 2 };

            /*****************************************
             * 3. Some withdraws, some deposits more *
             ****************************************/
            // Put enough DAI for user2 but not for user3
            const toUser2 = sent.user2 + profits.user2;
            const toUser3 = sent.user3 + profits.user3;
            const values = toUser2 + toUser3 - 1;
            await dai.transfer(vault.address, values, { from: user1 });
            await vault.methods['depositToVault(address,address[],uint256[])'](
                user1, [dai.address], [values], { from: defiops });
            await poolToken.mint(user1, values, { from: defiops });

            const before = {
                user2: await dai.balanceOf(user2),
                user3: await dai.balanceOf(user3),
                vault: await dai.balanceOf(vault.address)
            };

            // Withdraws DAI successfully
            await vault.methods['withdrawFromVault(address,address,uint256)'](
                user2, dai.address, toUser2, { from: defiops });

            // Ask to withdraw DAI when the contract doesn't have enough of them
            await vault.methods['withdrawFromVault(address,address,uint256)'](
                user3, dai.address, toUser3, { from: defiops });

            const requested = {
                user2: await vault.amountRequested(user2, dai.address),
                user3: await vault.amountRequested(user3, dai.address)
            };
            const claimable = { user3: await vault.claimableAmount(user3, dai.address) };
            const after = {
                user2: await dai.balanceOf(user2),
                user3: await dai.balanceOf(user3),
                vault: await dai.balanceOf(vault.address)
            };

            expect(after.user2.sub(before.user2).toNumber(), 'User2: should successfully withdraw').to.equal(toUser2);
            expect(requested.user2.toNumber(), 'User2: shouldn\'t have a requested amount').to.equal(0);
            expect(after.user3.sub(before.user3).toNumber(), 'User3: balance shouldn\'t change').to.equal(0);
            expect(requested.user3.toNumber(), 'User3: requested amount should be as in withdraw').to.equal(toUser3);
            expect(claimable.user3.toNumber(), 'User3: shouldn\'t have a claimable amount').to.equal(0);
            expect(before.vault.sub(after.vault).toNumber()).to.equal(toUser2);

            // Put enough DAI for the user3 to the vault
            await dai.transfer(vault.address, 1, { from: user1 });
            await vault.methods['depositToVault(address,address[],uint256[])'](
                user1, [dai.address], [1], { from: defiops });
            await poolToken.mint(user1, 1, { from: defiops });

            // Call operator action
            const user3BalanceBefore = await dai.balanceOf(user3);
            await vault.operatorAction(strategy.address, { from: defiops });

            const user3Stat = {
                requested: await vault.amountRequested(user3, dai.address),
                claimable: await vault.claimableAmount(user3, dai.address)
            };

            // Now the stablecoins could be withdrawn
            expect(user3Stat.claimable.toNumber(), 'User3: claimable amount should be as in withdraw')
                .to.equal(toUser3);
            expect(user3Stat.requested.toNumber(), 'User3: requested amount should be zero').to.equal(0);

            // Withdraw
            await vault.claimRequested(user3, { from: user3 });
            const user3BalanceAfter = await dai.balanceOf(user3);

            expect(user3BalanceAfter.sub(user3BalanceBefore).toNumber(), 'User3: all tokens should be withdrawn')
                .to.equal(toUser3);

            // User1 asks to withdraw DAI when the contract doesn't have enough of them
            const toUser1 = sent.user1 + profits.user1 + values + 1;
            await vault.methods['withdrawFromVault(address,address,uint256)'](
                user1, dai.address, toUser1, { from: defiops });

            await vault.operatorAction(strategy.address, { from: defiops });

            // User1 deposits more
            const sendMore = { user1: { dai: 30 } };
            await dai.transfer(vault.address, sendMore.user1.dai, { from: user1 });
            await vault.methods['depositToVault(address,address,uint256)'](
                user1, dai.address, sendMore.user1.dai, { from: defiops });
            await poolToken.mint(user2, sendMore.user1.dai, { from: defiops });

            await vault.operatorAction(strategy.address, { from: defiops });

            // Withdraws DAI successfully
            const user1BalanceBefore = await dai.balanceOf(user1);
            await vault.methods['withdrawFromVault(address,address,uint256)'](
                user1, dai.address, sendMore.user1.dai, { from: defiops });
            await vault.operatorAction(strategy.address, { from: defiops });
            await vault.claimRequested(user1, { from: user1 });

            const userBalanceAfter = await dai.balanceOf(user1);

            expect(userBalanceAfter.sub(user1BalanceBefore).toNumber(),
                'User1: all DAI should be withdrawn').to.equal(toUser1 + sendMore.user1.dai);

            /************************************************
             * 4. More deposits but without operator action *
             ***********************************************/
            // Deposits from users 1 & 2
            const more = { user1: 15, user2: 50 };
            await dai.transfer(vault.address, more.user1, { from: user1 });
            await vault.methods['depositToVault(address,address[],uint256[])'](user1,
                [dai.address], [more.user1], { from: defiops });
            // Send the same amount of pool tokens for user stablecoins
            await poolToken.mint(user1, more.user1, { from: defiops });

            await dai.transfer(vault.address, more.user2, { from: user2 });
            await vault.methods['depositToVault(address,address[],uint256[])'](user2,
                [dai.address], [more.user2], { from: defiops });
            // Send the same amount of pool tokens for user stablecoins
            await poolToken.mint(user2, more.user2, { from: defiops });

            /*********************************
             * 5. Everyone claims everything *
             ********************************/
            await vault.methods['withdrawFromVault(address,address[],uint256[])'](
                user1, [dai.address], [more.user1], { from: defiops });
            await vault.methods['withdrawFromVault(address,address[],uint256[])'](
                user2, [dai.address], [more.user2], { from: defiops });

            await vault.operatorAction(strategy.address, { from: defiops });

            await vault.claimRequested(user1, { from: user1 });
            await vault.claimRequested(user2, { from: user2 });
            await vault.claimRequested(user3, { from: user3 });

            // clearWithdrawRequests
            const balanceAfter = {
                user1: await dai.balanceOf(user1),
                user2: await dai.balanceOf(user2),
                user3: await dai.balanceOf(user3),
            };

            expect(balanceAfter.user1.toNumber(), 'User1: incorrect balance')
                .to.equal(balanceBefore.user1.toNumber() + profits.user1);
            expect(balanceAfter.user2.toNumber(), 'User2: incorrect balance')
                .to.equal(balanceBefore.user2.toNumber() + profits.user2);
            expect(balanceAfter.user3.toNumber(), 'User3: incorrect balance')
                .to.equal(balanceBefore.user3.toNumber() + profits.user3);

            expect((await dai.balanceOf(vault.address)).toNumber(), 'Vault: balance should be 0').to.equal(0);
            expect((await dai.balanceOf(protocolStub)).toNumber(), 'Protocol stub: balance should be 0').to.equal(0);

            expect((await vault.claimableAmount(user1, dai.address)).toNumber(),
                'User1: expect no claimable').to.equal(0);
            expect((await vault.claimableAmount(user2, dai.address)).toNumber(),
                'User2: expect no claimable').to.equal(0);
            expect((await vault.claimableAmount(user3, dai.address)).toNumber(),
                'User3: expect no claimable').to.equal(0);

            expect((await vault.amountOnHold(user1, dai.address)).toNumber(), 'User1: expect no on hold').to.equal(0);
            expect((await vault.amountOnHold(user2, dai.address)).toNumber(), 'User2: expect no on hold').to.equal(0);
            expect((await vault.amountOnHold(user3, dai.address)).toNumber(), 'User3: expect no on hold').to.equal(0);
        });

    });

});
