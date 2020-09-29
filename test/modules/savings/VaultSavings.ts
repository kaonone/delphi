import { 
    VaultProtocolStubContract, VaultProtocolStubInstance,
    TestErc20Contract, TestErc20Instance,
    VaultSavingsModuleContract, VaultSavingsModuleInstance,
    VaultPoolTokenContract, VaultPoolTokenInstance,
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
const advanceBlockAtTime = require("../../utils/advanceBlockAtTime");

const ERC20 = artifacts.require("TestERC20");

const VaultProtocol = artifacts.require("VaultProtocolStub");
const VaultSavings = artifacts.require("VaultSavingsModule");
const PoolToken = artifacts.require("VaultPoolToken");
const Pool = artifacts.require("Pool");
const AccessModule = artifacts.require("AccessModule");

contract("VaultSavings", async ([_, owner, user1, user2, user3, defiops, protocolStub, ...otherAccounts]) => {
    let globalSnap: Snapshot;
    let vaultProtocol: VaultProtocolStubInstance;
    let vaultSavings: VaultSavingsModuleInstance;
    let poolToken: VaultPoolTokenInstance
    let dai: TestErc20Instance;
    let usdc: TestErc20Instance;
    let busd: TestErc20Instance;
    let pool: PoolInstance;
    let accessModule: AccessModuleInstance;


    let blockTimeTravel = async(delta: BN) => {
        const block1 = await web3.eth.getBlock("pending");
        let tm = new BN(block1.timestamp);

        await advanceBlockAtTime(tm.add(delta).add(new BN(5)).toNumber());
    }


    before(async () => {
        pool = await Pool.new({from:owner});
        await (<any> pool).methods['initialize()']({from: owner});

        accessModule = await AccessModule.new({from: owner});
        await accessModule.methods['initialize(address)'](pool.address, {from: owner});

        await pool.set("access", accessModule.address, true, {from:owner});

        vaultSavings = await VaultSavings.new({from: owner});
        await (<any> vaultSavings).methods['initialize(address)'](pool.address, {from: owner});
        await vaultSavings.addDefiOperator(defiops, {from:owner});

        await pool.set("savings", vaultSavings.address, true, {from:owner});

        poolToken = await PoolToken.new({from: owner});
        await (<any> poolToken).methods['initialize(address,string,string)'](pool.address, "VaultSavings", "VLT", {from: owner});

        vaultProtocol = await VaultProtocol.new({from:owner});
        await (<any> vaultProtocol).methods['initialize(address,address)'](pool.address, poolToken.address, {from: owner});
        await vaultProtocol.addDefiOperator(vaultSavings.address, {from:owner});
        await vaultProtocol.addDefiOperator(defiops, {from:owner});

        await poolToken.addMinter(vaultSavings.address, {from:owner});
        await poolToken.addMinter(vaultProtocol.address, {from:owner});
        await poolToken.addMinter(defiops, {from:owner});

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
        beforeEach(async () => {
            await dai.approve(vaultProtocol.address, 80, {from: user1});
            await dai.approve(vaultProtocol.address, 50, {from: user2});
        });
        afterEach(async () => {
            await globalSnap.revert();
        });

        it('User gets LP tokens after the deposit through VaultSavings', async () => {
            
            await (<any> vaultSavings).methods['deposit(address,address[],uint256[])'](vaultProtocol.address, [dai.address], [80], {from:user1});

            let userPoolBalance = await poolToken.balanceOf(user1, {from: user1});
            expect(userPoolBalance.toNumber(), "Pool tokens are not minted for user1").to.equal(80);
        });

        it('Deposit through the VaultSavings goes to the Vault', async () => {
            let userBalanceBefore = await dai.balanceOf(user1, {from: user1});

            await (<any> vaultSavings).methods['deposit(address,address[],uint256[])'](vaultProtocol.address, [dai.address], [80], {from:user1});

            let vaultBalance = await dai.balanceOf(vaultProtocol.address, {from: owner});
            expect(vaultBalance.toNumber(), "Tokens from (1) are not transferred to vault").to.equal(80);

            let userOnHold = await vaultProtocol.amountOnHold(user1, dai.address, {from:owner});
            expect(userOnHold.toNumber(), "On-hold record for (1) was not created").to.equal(80);

            let userBalanceAfter = await dai.balanceOf(user1, {from: user1});
            expect(userBalanceBefore.sub(userBalanceAfter).toNumber(), "User (1) hasn't transfered tokens to vault").to.equal(80);
        });

        it('LP tokens are marked as on-hold while being in the Vault', async () => {
            await (<any> vaultSavings).methods['deposit(address,address[],uint256[])'](vaultProtocol.address, [dai.address], [80], {from:user1});
            await (<any> vaultSavings).methods['deposit(address,address[],uint256[])'](vaultProtocol.address, [dai.address], [50], {from:user2});

            let onHoldPool = await poolToken.onHoldBalanceOf(user1, {from:owner});
            expect(onHoldPool.toNumber(), "Pool tokens are not set on-hold for user (1)").to.equal(80);
            onHoldPool = await poolToken.onHoldBalanceOf(user2, {from:owner});
            expect(onHoldPool.toNumber(), "Pool tokens are not set on-hold for user (2)").to.equal(50);
        });
    });

    describe('Operator resolves deposits through the VaultSavings', () => {
        beforeEach(async () => {
            await dai.approve(vaultProtocol.address, 80, {from: user1});
            await (<any> vaultSavings).methods['deposit(address,address[],uint256[])'](vaultProtocol.address, [dai.address], [80], {from:user1});

            await dai.approve(vaultProtocol.address, 50, {from: user2});
            await (<any> vaultSavings).methods['deposit(address,address[],uint256[])'](vaultProtocol.address, [dai.address], [50], {from:user2});
        });
        afterEach(async () => {
            await globalSnap.revert();
        });

        it('LP tokens are unmarked from being on-hold after deposit is resolved by operator', async () => {
            await vaultSavings.handleWithdrawRequests(vaultProtocol.address, {from: defiops});


            let onHoldPool = await poolToken.onHoldBalanceOf(user1, {from:owner});
            expect(onHoldPool.toNumber(), "Pool tokens are not earning yield for user (1)").to.equal(0);
            onHoldPool = await poolToken.onHoldBalanceOf(user2, {from:owner});
            expect(onHoldPool.toNumber(), "Pool tokens are not earning yield for user (2)").to.equal(0);
        });

        it('First deposit (no yield earned yet)', async () => {
            let before = {
                userBalance1 : await dai.balanceOf(user1, {from: user1}),
                userBalance2 : await dai.balanceOf(user2, {from: user2}),
                poolBalance1 : await poolToken.balanceOf(user1, {from: user1}),
                poolBalance2 : await poolToken.balanceOf(user2, {from: user2})
            }
            
            await vaultSavings.handleWithdrawRequests(vaultProtocol.address, {from: defiops});

            let vaultBalance = await dai.balanceOf(vaultProtocol.address, {from: owner});
            expect(vaultBalance.toNumber(), "Tokens are not deposited from vault").to.equal(0);

            let protocolBalance = await dai.balanceOf(protocolStub, {from:owner});
            expect(protocolBalance.toNumber(), "Tokens are not deposited").to.equal(130);

            let userOnHold = await vaultProtocol.amountOnHold(user1, dai.address, {from:owner});
            expect(userOnHold.toNumber(), "On-hold record for (1) was not deleted").to.equal(0);

            userOnHold = await vaultProtocol.amountOnHold(user2, dai.address, {from:owner});
            expect(userOnHold.toNumber(), "On-hold record for (2) was not deleted").to.equal(0);


            let poolBalance = await poolToken.balanceOf(poolToken.address, {from: owner});
            expect(poolBalance.toNumber(), "No new pool tokens minted").to.equal(0);

            let after = {
                userBalance1 : await dai.balanceOf(user1, {from: user1}),
                userBalance2 : await dai.balanceOf(user2, {from: user2}),
                poolBalance1 : await poolToken.balanceOf(user1, {from: user1}),
                poolBalance2 : await poolToken.balanceOf(user2, {from: user2})
            }

            expect(before.userBalance1.sub(after.userBalance1).toNumber(), "User (1) should not receive any tokens").to.equal(0);
            expect(before.userBalance2.sub(after.userBalance2).toNumber(), "User (2) should not receive any tokens").to.equal(0);
            expect(before.poolBalance1.sub(after.poolBalance1).toNumber(), "User (1) should not receive new pool tokens").to.equal(0);
            expect(before.poolBalance2.sub(after.poolBalance2).toNumber(), "User (2) should not receive new pool tokens").to.equal(0);
        });

        it('First deposit (no yield available)', async () => {
            let before = {
                yieldBalance1 : await poolToken.calculateUnclaimedDistributions(user1, {from: user1}),
                yieldBalance2 : await poolToken.calculateUnclaimedDistributions(user2, {from: user2})
            }
            
            await vaultSavings.handleWithdrawRequests(vaultProtocol.address, {from: defiops});

            let after = {
                yieldBalance1 : await poolToken.calculateUnclaimedDistributions(user1, {from: user1}),
                yieldBalance2 : await poolToken.calculateUnclaimedDistributions(user2, {from: user2})
            }

            expect(before.yieldBalance1.sub(after.yieldBalance1).toNumber(), "No yield for user (1) yet").to.equal(0);
            expect(before.yieldBalance2.sub(after.yieldBalance2).toNumber(), "No yield for user (2) yet").to.equal(0);
        });


        it('Deposit with some users earned yield', async () => {
        });

    });

    describe('Yield distribution', () => {
        beforeEach(async () => {
            await dai.approve(vaultProtocol.address, 80, {from: user1});
            await (<any> vaultSavings).methods['deposit(address,address[],uint256[])'](vaultProtocol.address, [dai.address], [80], {from:user1});

            await dai.approve(vaultProtocol.address, 50, {from: user2});
            await (<any> vaultSavings).methods['deposit(address,address[],uint256[])'](vaultProtocol.address, [dai.address], [50], {from:user2});
        });
        afterEach(async () => {
            await globalSnap.revert();
        });
        //The user gets yeild only if he has no on-hold deposits

        it('Yield is distributed for the user after new tokens minted', async () => {
            await vaultSavings.handleWithdrawRequests(vaultProtocol.address, {from: defiops});

            //Add yield to the protocol
            await dai.transfer(protocolStub, 26, {from:owner});

            await vaultSavings.distributeYield({from:defiops});

            //16 new LP tokens for 80/130
            let unclaimedTokens = await poolToken.calculateUnclaimedDistributions(user1, {from:owner});
            expect(unclaimedTokens.toNumber(), "No yield for user (1) yet").to.equal(16);

            //additional deposit
            await dai.approve(vaultProtocol.address, 20, {from: user1});
            await (<any> vaultSavings).methods['deposit(address,address[],uint256[])'](vaultProtocol.address, [dai.address], [20], {from:user1});

            //Yield distributed
            unclaimedTokens = await poolToken.calculateUnclaimedDistributions(user1, {from:owner});
            expect(unclaimedTokens.toNumber(), "No additional yield for user (1) should be distributed").to.equal(0);

            //80 LP + 16 LP yield + 20 on-hold LP
            let poolBalance = await poolToken.balanceOf(user1);
            expect(poolBalance.toNumber(), "Incorrect number of tokens minted").to.equal(116);

            //On-hold tokens do not participate in distribution
            let distrBalance = await poolToken.distributionBalanceOf(user1, {from:owner});
            expect(distrBalance.toNumber(), "Ob-hold tokens should not participate in distribution").to.equal(96);
        });

        it('Additional deposit does not influence yield while being on-hold', async () => {
            await vaultSavings.handleWithdrawRequests(vaultProtocol.address, {from: defiops});

            //additional deposit
            await dai.approve(vaultProtocol.address, 20, {from: user1});
            await (<any> vaultSavings).methods['deposit(address,address[],uint256[])'](vaultProtocol.address, [dai.address], [20], {from:user1});

            //Add yield to the protocol
            await dai.transfer(protocolStub, 26, {from:owner});

            await vaultSavings.distributeYield({from:defiops});

            //16 new LP tokens for 80/130
            let unclaimedTokens = await poolToken.calculateUnclaimedDistributions(user1, {from:owner});
            expect(unclaimedTokens.toNumber(), "No yield for user (1) yet").to.equal(16);

            //additional deposit will not participate in distribution
            let distrBalance = await poolToken.distributionBalanceOf(user1, {from:owner});
            expect(distrBalance.toNumber(), "Ob-hold tokens should not participate in distribution").to.equal(80);
        });
    });


    describe('Full cycle', () => {
        beforeEach(async () => {
            dai.approve(vaultProtocol.address, 10000, {from:protocolStub});
        });
        afterEach(async () => {
            await globalSnap.revert();
        });

        it('Full cycle of deposit->yield->withdraw', async () => {
    //Preliminary
        //Deposit 1
            await dai.approve(vaultProtocol.address, 80, {from: user1});
            await (<any> vaultSavings).methods['deposit(address,address[],uint256[])'](vaultProtocol.address, [dai.address], [80], {from:user1});
    
        //Deposit 2
            await dai.approve(vaultProtocol.address, 50, {from: user2});
            await (<any> vaultSavings).methods['deposit(address,address[],uint256[])'](vaultProtocol.address, [dai.address], [50], {from:user2});

            //Operator resolves deposits
            await vaultSavings.handleWithdrawRequests(vaultProtocol.address, {from: defiops});

            //no yield yet - user balances are unchanged
            let user1PoolBalance = await poolToken.balanceOf(user1, {from: user1});
            expect(user1PoolBalance.toNumber(), "No new pool tokens should be minted for user1").to.equal(80);

            let user2PoolBalance = await poolToken.balanceOf(user2, {from: user2});
            expect(user2PoolBalance.toNumber(), "No new pool tokens should be  minted for user2").to.equal(50);

            let poolBalance = await poolToken.balanceOf(poolToken.address, {from: owner});
            expect(poolBalance.toNumber(), "No new pool tokens minted").to.equal(0);

            let unclaimedTokens = await poolToken.calculateUnclaimedDistributions(user1, {from:owner});
            expect(unclaimedTokens.toNumber(), "No yield for user (1) yet").to.equal(0);

            unclaimedTokens = await poolToken.calculateUnclaimedDistributions(user2, {from:owner});
            expect(unclaimedTokens.toNumber(), "No yield for user (2) yet").to.equal(0);

    //First case
        //Add yield to the protocol
            await dai.transfer(protocolStub, 26, {from:owner});

        //Deposit from User3
            await dai.approve(vaultProtocol.address, 20, {from: user3});
            await (<any> vaultSavings).methods['deposit(address,address[],uint256[])'](vaultProtocol.address, [dai.address], [20], {from:user3});

            let user3PoolBalance = await poolToken.balanceOf(user3, {from: user3});
            expect(user3PoolBalance.toNumber(), "Pool tokens are not minted for user3").to.equal(20);

        //Operator resolves deposits
            await vaultSavings.handleWithdrawRequests(vaultProtocol.address, {from: defiops});
            //Yield from pool is distributed before the new deposit (on-hold deposit is not counted)
            //26 tokens of yield for deposits 80 + 50 = 130, 16 + 10 tokens of yield

            poolBalance = await poolToken.balanceOf(poolToken.address, {from: owner});
            expect(poolBalance.toNumber(), "Yield tokens are not minted").to.equal(26);

            //Yield is not claimed yet
            user1PoolBalance = await poolToken.balanceOf(user1, {from:user1});
            expect(user1PoolBalance.toNumber(), "Yield tokens should not be claimed yet for user1").to.equal(80);

            user2PoolBalance = await poolToken.balanceOf(user2, {from:user2});
            expect(user2PoolBalance.toNumber(), "Yield tokens should not be claimed yet for user2").to.equal(50);

            user3PoolBalance = await poolToken.balanceOf(user3, {from:user3});
            expect(user3PoolBalance.toNumber(), "Yield tokens should not be claimed yet for user3").to.equal(20);

            //Yield ready fo claim
            unclaimedTokens = await poolToken.calculateUnclaimedDistributions(user1, {from:owner});
            expect(unclaimedTokens.toNumber(), "Yield was not distributed for user1").to.equal(16);

            unclaimedTokens = await poolToken.calculateUnclaimedDistributions(user2, {from:owner});
            expect(unclaimedTokens.toNumber(), "Yield was not distributed for user2").to.equal(10);

            unclaimedTokens = await poolToken.calculateUnclaimedDistributions(user3, {from:owner});
            expect(unclaimedTokens.toNumber(), "Yield should not be distributed for user1").to.equal(0);
            
        //Additional deposit from user1
            await dai.approve(vaultProtocol.address, 20, {from: user1});
            await (<any> vaultSavings).methods['deposit(address,address[],uint256[])'](vaultProtocol.address, [dai.address], [20], {from:user1});

            //Since new tokens are minted, user1 gets distribution
            unclaimedTokens = await poolToken.calculateUnclaimedDistributions(user1, {from:owner});
            expect(unclaimedTokens.toNumber(), "Yield was transfered to user1").to.equal(0);

            user1PoolBalance = await poolToken.balanceOf(user1, {from: user1});
            //80 first deposit + 20 on-hold + 16 yield LP
            expect(user1PoolBalance.toNumber(), "No new pool tokens minted for user1").to.equal(116);


        //User2 claims yield
            await poolToken.methods['claimDistributions(address)'](user2, {from: user2});

            unclaimedTokens = await poolToken.calculateUnclaimedDistributions(user2, {from:owner});
            expect(unclaimedTokens.toNumber(), "Yield was not claimed by user2").to.equal(0);

            user2PoolBalance = await poolToken.balanceOf(user2, {from: user2});
            //50 LP tokens + 10 LP yield
            expect(user2PoolBalance.toNumber(), "No new pool tokens minted for user2").to.equal(60);

    //Second case
            //Make sure, that all LP tokens are working
            await vaultSavings.handleWithdrawRequests(vaultProtocol.address, {from: defiops});
            
        //Withdraw by user 2
            await vaultSavings.withdraw(vaultProtocol.address, dai.address, 60, 60, {from:user2});
            
            //LP tokens from user2 are burned
            user2PoolBalance = await poolToken.balanceOf(user2, {from: user2});
            expect(user2PoolBalance.toNumber(), "LP tokens were not burned for user2").to.equal(0);

            //Withdraw request is created
            let requestedAmount = await vaultProtocol.amountRequested(user2, dai.address);
            expect(requestedAmount.toNumber(), "Request should be created").to.equal(60);
  
        //Add yield to the protocol
            //For ease of calculations: 34 = 29 + 5 -> in proportion for 116/136 (user1) and 20/136 (user3)
            await dai.transfer(protocolStub, 34, {from:owner});

            //Request handling

            //Imitate distribution period
            await blockTimeTravel(await vaultSavings.DISTRIBUTION_AGGREGATION_PERIOD());
            
            await vaultSavings.handleWithdrawRequests(vaultProtocol.address, {from: defiops});

            //User2 can claim his requested tokens
            let claimableTokens = await vaultProtocol.claimableAmount(user2, dai.address);
            expect(claimableTokens.toNumber(), "No tokens can be claimed by user2").to.equal(60);

            let balanceBefore = await dai.balanceOf(user2);
            await vaultSavings.claimAllRequested(vaultProtocol.address, {from:user2});
            let balanceAfter = await dai.balanceOf(user2);

            expect(balanceAfter.sub(balanceBefore).toNumber(), "Requested tokens are not claimed by user2").to.equal(60);

            //Yield distribution (user2 is without LP tokens - only 1 and 3 receive yield)
            //User1: 116 LP + 29 LP yield
            unclaimedTokens = await poolToken.calculateUnclaimedDistributions(user1, {from:owner});
            expect(unclaimedTokens.toNumber(), "Yield was not distributed for user1 (second case)").to.equal(29);

            user1PoolBalance = await poolToken.balanceOf(user1, {from: user1});
            expect(user1PoolBalance.toNumber(), "No new pool tokens should be minted for user1 (seond case)").to.equal(116);

            //User2: 0 LP + 0 LP yield
            unclaimedTokens = await poolToken.calculateUnclaimedDistributions(user2, {from:owner});
            expect(unclaimedTokens.toNumber(), "Yield should not be distributed for user2 (second case)").to.equal(0);

            user2PoolBalance = await poolToken.balanceOf(user2, {from: user2});
            expect(user2PoolBalance.toNumber(), "No new pool tokens should be minted for user1 (seond case)").to.equal(0);

            //User3: 20 LP + 5 LP yield
            unclaimedTokens = await poolToken.calculateUnclaimedDistributions(user3, {from:owner});
            expect(unclaimedTokens.toNumber(), "Yield was not distributed for user1 (second case)").to.equal(5);

            user3PoolBalance = await poolToken.balanceOf(user3, {from: user3});
            expect(user3PoolBalance.toNumber(), "No new pool tokens should be minted for user1 (seond case)").to.equal(20);

            //Users claim yield
            await poolToken.methods['claimDistributions(address)'](user1, {from: user1});
            await poolToken.methods['claimDistributions(address)'](user3, {from: user3});

        //Third case
            //User1 requests particular withdraw - LP for requests creation are sent to the protocol

            //Add yield to the protocol

            //Distribute yield

            //Yield from pool is distributed before the request resolving (user1 and user3 receive yield according to their LP tokens amounts)

            //Operator resolves withdraw requests
            
            //Unclaimed amounts are not changed
        });

    });
});