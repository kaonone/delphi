import { 
    VaultProtocolStubContract, VaultProtocolStubInstance,
    TestErc20Contract, TestErc20Instance,
    VaultSavingsModuleContract, VaultSavingsModuleInstance,
    PoolTokenContract, PoolTokenInstance,
    PoolContract, PoolInstance,
    AccessModuleContract, AccessModuleInstance
} from "../../../types/truffle-contracts/index";

// tslint:disable-next-line:no-var-requires
const { BN, constants, expectEvent, shouldFail, time } = require("@openzeppelin/test-helpers");
// tslint:disable-next-line:no-var-requires
import Snapshot from "../../utils/snapshot";
const { expect, should } = require('chai');

const expectRevert= require("../../utils/expectRevert");
const expectEqualBN = require("../../utils/expectEqualBN");
const w3random = require("../../utils/w3random");

const ERC20 = artifacts.require("TestERC20");

const VaultProtocol = artifacts.require("VaultProtocolStub");
const VaultSavings = artifacts.require("VaultSavingsModule");
const PoolToken = artifacts.require("PoolToken");
const Pool = artifacts.require("Pool");
const AccessModule = artifacts.require("AccessModule");

contract("VaultSavings", async ([_, owner, user1, user2, user3, defiops, protocolStub, ...otherAccounts]) => {
    let globalSnap: Snapshot;
    let vaultProtocol: VaultProtocolStubInstance;
    let vaultSavings: VaultSavingsModuleInstance;
    let poolToken: PoolTokenInstance
    let dai: TestErc20Instance;
    let usdc: TestErc20Instance;
    let busd: TestErc20Instance;
    let pool: PoolInstance;
    let accessModule: AccessModuleInstance;


    before(async () => {
        pool = await Pool.new({from:owner});
        await (<any> pool).methods['initialize()']({from: owner});

        accessModule = await AccessModule.new({from: owner});
        await accessModule.methods['initialize(address)'](pool.address, {from: owner});

        await pool.set("access", accessModule.address, true, {from:owner});

        vaultSavings = await VaultSavings.new({from: owner});
        await (<any> vaultSavings).methods['initialize(address)'](pool.address, {from: owner});

        await pool.set("savings", vaultSavings.address, true, {from:owner});

        poolToken = await PoolToken.new({from: owner});
        await (<any> poolToken).methods['initialize(address,string,string)'](pool.address, "VaultSavings", "VLT", {from: owner});

        await poolToken.addMinter(vaultSavings.address, {from:owner});
        await poolToken.addMinter(defiops, {from:owner});

        vaultProtocol = await VaultProtocol.new({from:owner});
        await (<any> vaultProtocol).methods['initialize(address)'](pool.address, {from: owner});
        await vaultProtocol.addDefiOperator(vaultSavings.address, {from:owner});
        await vaultProtocol.addDefiOperator(defiops, {from:owner});

        //Deposit token 1
        dai = await ERC20.new({from:owner});
        await dai.initialize("DAI", "DAI", 18, {from:owner})
        //Deposit token 2
        usdc = await ERC20.new({from:owner});
        await usdc.initialize("USDC", "USDC", 18, {from:owner})
        //Deposit token 3
        busd = await ERC20.new({from:owner});
        await busd.initialize("BUSD", "BUSD", 18, {from:owner})

        await dai.transfer(user1, 1000, {from:owner});
        await dai.transfer(user2, 1000, {from:owner});
        await dai.transfer(user3, 1000, {from:owner});

        await usdc.transfer(user1, 1000, {from:owner});
        await usdc.transfer(user2, 1000, {from:owner});
        await usdc.transfer(user3, 1000, {from:owner});

        await busd.transfer(user1, 1000, {from:owner});
        await busd.transfer(user2, 1000, {from:owner});
        await busd.transfer(user3, 1000, {from:owner});

        await vaultProtocol.registerTokens([dai.address, usdc.address, busd.address], {from: defiops})
        await vaultProtocol.setProtocol(protocolStub, {from: defiops});

        await vaultSavings.registerProtocol(vaultProtocol.address, poolToken.address, {from: owner});

        globalSnap = await Snapshot.create(web3.currentProvider);
    });


    describe('Deposit into the vault', () => {
    });

    describe('Yield distribution', () => {
        //The user gets yeild only if he has no on-hold deposits

    });




    describe('Full cycle', () => {
        afterEach(async () => {
            await globalSnap.revert();
        });

        it('Full cycle of deposit->yield->withdraw', async () => {
        //Preliminary
        //Deposit 1
            let user1BalanceBefore = await dai.balanceOf(user1, {from: user1});
            await dai.approve(vaultProtocol.address, 80, {from: user1});
            await dai.approve(vaultSavings.address, 80, {from: user1});
            await (<any> vaultSavings).methods['deposit(address,address[],uint256[])'](vaultProtocol.address, [dai.address], [80], {from:user1});

            let user1PoolBalance = await poolToken.balanceOf(user1, {from: user1});
            expect(user1PoolBalance.toNumber(), "Pool tokens are not minted for user1").to.equal(80);

            let vaultBalance = await dai.balanceOf(vaultProtocol.address, {from: owner});
            expect(vaultBalance.toNumber(), "Tokens from (1) are not transferred to vault").to.equal(80);

            let userOnHold = await vaultProtocol.amountOnHold(user1, dai.address, {from:owner});
            expect(userOnHold.toNumber(), "On-hold record for (1) was not created").to.equal(80);

            let user1BalanceAfter = await dai.balanceOf(user1, {from: user1});
            expect(user1BalanceBefore.sub(user1BalanceAfter).toNumber(), "User (1) hasn't transfered tokens to vault").to.equal(80);
        //Deposit 2
            let user2BalanceBefore = await dai.balanceOf(user2, {from: user2});
            await dai.approve(vaultProtocol.address, 50, {from: user2});
            await dai.approve(vaultSavings.address, 50, {from: user2});
            await (<any> vaultSavings).methods['deposit(address,address[],uint256[])'](vaultProtocol.address, [dai.address], [50], {from:user2});

            let user2PoolBalance = await poolToken.balanceOf(user2, {from: user2});
            expect(user2PoolBalance.toNumber(), "Pool tokens are not minted for user2").to.equal(50);

            vaultBalance = await dai.balanceOf(vaultProtocol.address, {from: owner});
            expect(vaultBalance.toNumber(), "Tokens from (2) are not transferred to vault").to.equal(130);

            userOnHold = await vaultProtocol.amountOnHold(user2, dai.address, {from:owner});
            expect(userOnHold.toNumber(), "On-hold record for (2) was not created").to.equal(50);

            let user2BalanceAfter = await dai.balanceOf(user2, {from: user2});
            expect(user2BalanceBefore.sub(user2BalanceAfter).toNumber(), "User (2) hasn't transfered tokens to vault").to.equal(50);

        //Operator resolves deposits
            user1BalanceBefore = await dai.balanceOf(user1, {from: user1});
            user2BalanceBefore = await dai.balanceOf(user2, {from: user2});
            await vaultSavings.handleWithdrawRequests(vaultProtocol.address, {from: owner});

            vaultBalance = await dai.balanceOf(vaultProtocol.address, {from: owner});
            expect(vaultBalance.toNumber(), "Tokens are not deposited from vault").to.equal(0);

            //Deposits are in the protocol
            let protocolBalance = await dai.balanceOf(protocolStub, {from:owner});
            expect(protocolBalance.toNumber(), "Tokens are not deposited").to.equal(130);

            userOnHold = await vaultProtocol.amountOnHold(user1, dai.address, {from:owner});
            expect(userOnHold.toNumber(), "On-hold record for (1) was not deleted").to.equal(0);

            userOnHold = await vaultProtocol.amountOnHold(user2, dai.address, {from:owner});
            expect(userOnHold.toNumber(), "On-hold record for (2) was not deleted").to.equal(0);

            //no yield yet - user balances are unchanged
            user1BalanceAfter = await dai.balanceOf(user1, {from: user1});
            expect(user1BalanceBefore.sub(user1BalanceAfter).toNumber(), "User (1) should not receive any tokens").to.equal(0);

            user2BalanceAfter = await dai.balanceOf(user2, {from: user2});
            expect(user2BalanceBefore.sub(user2BalanceAfter).toNumber(), "User (2) should not receive any tokens").to.equal(0);

            user1PoolBalance = await poolToken.balanceOf(user1, {from: user1});
            expect(user1PoolBalance.toNumber(), "User (1) should not receive new pool tokens").to.equal(80);

            user2PoolBalance = await poolToken.balanceOf(user2, {from: user2});
            expect(user2PoolBalance.toNumber(), "User (2) should not receive new pool tokens").to.equal(50);

            let poolBalance = await poolToken.balanceOf(poolToken.address, {from: owner});
            expect(poolBalance.toNumber(), "No new pool tokens minted").to.equal(0);

        //First case
            //Add yield to the protocol
            //Send tokens to protocol stub

            //Add yield for the strategy to the protocol
            //add dai as a strategy yield

            //New deposit from User3
//            await (<any> vaultSavings).methods['deposit(address,address,uint256)'](user3, dai.address, 120, {from:user3});
            //expect user to get LP tokens

            //Operator checks yield from strategy
            //Yield distribution from strategy (on-hold deposit is not counted)

            //Yield from pool is distributed before the new deposit (on-hold deposit is not counted)
            //Operator resolves deposits


        //Second case
            //Add yield to the protocol
            //Add yield for the strategy to the protocol

            //Withdraw by user 2 - LP for requests creation are sent to the protocol


            //Operator checks yield from strategy
            //Yield distribution from strategy (user2 is without LP tokens - only 1 and 3 receive yield)

            //Yield from pool is distributed before the request resolving (user2 is without LP tokens - only 1 and 3 receive yield)
            //Operator resolves withdraw requests

            //User2 can claim the withdraw

        //Third case
            //Add yield to the protocol
            //Add yield for the strategy to the protocol

            //User1 requests particular withdraw - LP for requests creation are sent to the protocol


            //Operator checks yield from strategy
            //Yield distribution from strategy (user1 and user3 receive yield according to their LP tokens amounts)

            //Yield from pool is distributed before the request resolving (user1 and user3 receive yield according to their LP tokens amounts)
            //Operator resolves withdraw requests
        });

    });
});