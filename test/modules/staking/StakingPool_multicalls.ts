import { 
    FreeErc20Contract,FreeErc20Instance,
    PoolContract, PoolInstance,
    RewardVestingModuleContract, RewardVestingModuleInstance,
    StakingPoolContract,StakingPoolInstance,
    CallExecutorContract,CallExecutorInstance
} from "../../../types/truffle-contracts/index";

const { BN, constants, expectEvent, shouldFail, time } = require("@openzeppelin/test-helpers");
const { promisify } = require('util');
import Snapshot from "../../utils/snapshot";
const should = require("chai").should();
const expect = require("chai").expect;
const expectRevert= require("../../utils/expectRevert");
const expectEqualBN = require("../../utils/expectEqualBN");
const w3random = require("../../utils/w3random");

const FreeERC20 = artifacts.require("FreeERC20");
const Pool = artifacts.require("Pool");
const RewardVestingModule = artifacts.require("RewardVestingModule");
const StakingPool = artifacts.require("StakingPool");
const CallExecutor = artifacts.require("CallExecutor");

contract("StakingPool:multicalls", async ([owner, user, ...otherAccounts]) => {
    const ZERO_BN = new BN("0");
    const ZERO_DATA = "0x";
    const REWARD_EPOCH_DURATION = 24*60*60;
    const LOCK_DURATION = 2*60*60;

    let snap: Snapshot;
    let callExecutor:CallExecutorInstance;
    let akro: FreeErc20Instance;
    let adel: FreeErc20Instance;
    let pool: PoolInstance;
    let rewardVestingModule: RewardVestingModuleInstance;
    let stakingPool: StakingPoolInstance;
    let stakingPoolContract = new web3.eth.Contract((<any>StakingPool).abi);

    before(async () => {
        callExecutor = await CallExecutor.new();

        akro = await FreeERC20.new();
        await (<any> akro).methods['initialize(string,string)']("Akropolis","AKRO");

        adel = await FreeERC20.new();
        await (<any> adel).methods['initialize(string,string)']("Akropolis Delphi","ADEL");

        pool = await Pool.new();
        await pool.methods['initialize()']();

        stakingPool = await StakingPool.new();
        await stakingPool.methods['initialize(address,address,uint256)'](pool.address, akro.address, 0);

        rewardVestingModule = await RewardVestingModule.new();
        await rewardVestingModule.methods['initialize(address)'](pool.address);

        //Setup
        await pool.set("akro", akro.address, false);
        await pool.set("adel", adel.address, false);
        await pool.set("staking", stakingPool.address, false);

        await stakingPool.setRewardVesting(rewardVestingModule.address);
        await stakingPool.registerRewardToken(akro.address);
        await stakingPool.registerRewardToken(adel.address);
        await rewardVestingModule.setDefaultEpochLength(REWARD_EPOCH_DURATION);
        await rewardVestingModule.registerRewardToken(stakingPool.address, akro.address, 0);
        await rewardVestingModule.registerRewardToken(stakingPool.address, adel.address, 0);

        //Prepare liquidity
        await akro.methods['mint(address,uint256)'](owner, web3.utils.toWei('1000000000'));
        await adel.methods['mint(address,uint256)'](owner, web3.utils.toWei('1000000000'));

        //Prepare rewards
        let rwrd = new BN(web3.utils.toWei('1000'));
        await akro.approve(rewardVestingModule.address, web3.utils.toWei('100000000000000'));
        await adel.approve(rewardVestingModule.address, web3.utils.toWei('100000000000000'));
        for(let e = 0; e < 3; e++) {
            await rewardVestingModule.addRewards(
               [stakingPool.address, stakingPool.address],
               [akro.address, adel.address],
               [0,0],
               [rwrd,rwrd.divn(e+1)]
            );
        }

        //Save snapshot
        //snap = await Snapshot.create(web3.currentProvider);

        // console.log('user', user);
        // console.log('otherAccounts[0]', otherAccounts[0]);
        // console.log('executor', callExecutor.address);

    });

    it('should execute scenario: stake, stakeFor, withdrawReqards, unstakeAll', async () => {
        await callExecutor.clearCalls();

        let mintAmount = new BN(web3.utils.toWei('10000'));
        await akro.allocateTo(callExecutor.address, mintAmount);
        await addAllowanceAction(akro.address, stakingPool.address, mintAmount);

        let stakeAmount1 = w3random.interval(100, 500, 'ether');
        await addStakeAction(stakeAmount1);

        let stakeAmount2 = w3random.interval(100, 500, 'ether');
        await addStakeForAction(user, stakeAmount2);

        await addWithdrawRewardsAction();

        await addUnstakeAllUnlockedAction();

        const before = {
            userBalance: await akro.balanceOf(callExecutor.address),
            executorBalance: await akro.balanceOf(callExecutor.address),
        }

        await callExecutor.execute({from:user});

        const after = {
            userBalance: await akro.balanceOf(callExecutor.address),
            executorBalance: await akro.balanceOf(callExecutor.address),
        }

        expect(after.userBalance).to.be.bignumber.eq(before.userBalance);
        expect(after.executorBalance).to.be.bignumber.eq(before.executorBalance);
    });

    it('should execute scenario: stake, unstakeAll - repeat 10 times', async () => {
        await callExecutor.clearCalls();

        let mintAmount = new BN(web3.utils.toWei('100000'));
        await akro.allocateTo(callExecutor.address, mintAmount);
        await addAllowanceAction(akro.address, stakingPool.address, mintAmount);

        for(let i=0; i<10; i++) {
            let stakeAmount = w3random.interval(100, 500, 'ether');
            await addStakeAction(stakeAmount);
            await addUnstakeAllUnlockedAction();
        }

        const before = {
            userBalance: await akro.balanceOf(callExecutor.address),
            executorBalance: await akro.balanceOf(callExecutor.address),
        }

        await callExecutor.execute({from:user});

        const after = {
            userBalance: await akro.balanceOf(callExecutor.address),
            executorBalance: await akro.balanceOf(callExecutor.address),
        }

        expect(after.userBalance).to.be.bignumber.eq(before.userBalance);
        expect(after.executorBalance).to.be.bignumber.eq(before.executorBalance);
    });


    it('should execute scenario: stake, stakeFor, withdrawReqards, unstakeAll - with rewards', async () => {
        await callExecutor.clearCalls();

        let mintAmount = new BN(web3.utils.toWei('10000'));
        await akro.allocateTo(callExecutor.address, mintAmount);
        await addAllowanceAction(akro.address, stakingPool.address, mintAmount);

        let stakeAmount0 = w3random.interval(100, 500, 'ether');
        await addStakeAction(stakeAmount0);
        await callExecutor.execute({from:user});
        await callExecutor.clearCalls();


        let stakeAmount1 = w3random.interval(100, 500, 'ether');
        await addStakeAction(stakeAmount1);

        let stakeAmount2 = w3random.interval(100, 500, 'ether');
        await addStakeForAction(user, stakeAmount2);

        await addWithdrawRewardsAction();

        await addUnstakeAllUnlockedAction();


        await time.increase(REWARD_EPOCH_DURATION);
        await stakingPool.claimRewardsFromVesting();

        const before = {
            userBalanceAkro: await akro.balanceOf(user),
            userBalanceAdel: await adel.balanceOf(user),
            executorBalanceAkro: await akro.balanceOf(callExecutor.address),
            executorBalanceAdel: await adel.balanceOf(callExecutor.address),
            executorRewardBalanceAkro: await stakingPool.rewardBalanceOf(callExecutor.address, akro.address),
            executorRewardBalanceAdel: await stakingPool.rewardBalanceOf(callExecutor.address, adel.address)
        }

        await callExecutor.execute({from:user});

        const after = {
            userBalanceAkro: await akro.balanceOf(user),
            userBalanceAdel: await adel.balanceOf(user),
            executorBalanceAkro: await akro.balanceOf(callExecutor.address),
            executorBalanceAdel: await adel.balanceOf(callExecutor.address),
            executorRewardBalanceAkro: await stakingPool.rewardBalanceOf(callExecutor.address, akro.address),
            executorRewardBalanceAdel: await stakingPool.rewardBalanceOf(callExecutor.address, adel.address)
        }

        expect(after.userBalanceAkro).to.be.bignumber.eq(before.userBalanceAkro);
        expect(after.userBalanceAdel).to.be.bignumber.eq(before.userBalanceAdel);
        expect(after.executorBalanceAkro).to.be.bignumber.eq(before.executorBalanceAkro.add(before.executorRewardBalanceAkro).add(stakeAmount0));
        expect(after.executorBalanceAdel).to.be.bignumber.eq(before.executorBalanceAdel.add(before.executorRewardBalanceAdel));
        expect(after.executorRewardBalanceAkro).to.be.bignumber.eq(ZERO_BN);
        expect(after.executorRewardBalanceAdel).to.be.bignumber.eq(ZERO_BN);

    });

    it('should execute scenario: stake, unstakeAll - repeat 10 times  - with rewards', async () => {
        await callExecutor.clearCalls();

        let mintAmount = new BN(web3.utils.toWei('100000'));
        await akro.allocateTo(callExecutor.address, mintAmount);
        await addAllowanceAction(akro.address, stakingPool.address, mintAmount);

        let stakeAmount0 = w3random.interval(100, 500, 'ether');
        await addStakeAction(stakeAmount0);
        await callExecutor.execute({from:user});
        await callExecutor.clearCalls();


        for(let i=0; i<10; i++) {
            let stakeAmount = w3random.interval(100, 500, 'ether');
            await addStakeAction(stakeAmount);
            await addUnstakeAllUnlockedAction();
        }

        await time.increase(REWARD_EPOCH_DURATION);
        await stakingPool.claimRewardsFromVesting();

        const before = {
            userBalanceAkro: await akro.balanceOf(user),
            userBalanceAdel: await adel.balanceOf(user),
            executorBalanceAkro: await akro.balanceOf(callExecutor.address),
            executorBalanceAdel: await adel.balanceOf(callExecutor.address),
            executorRewardBalanceAkro: await stakingPool.rewardBalanceOf(callExecutor.address, akro.address),
            executorRewardBalanceAdel: await stakingPool.rewardBalanceOf(callExecutor.address, adel.address)
        }

        await callExecutor.execute({from:user});

        const after = {
            userBalanceAkro: await akro.balanceOf(user),
            userBalanceAdel: await adel.balanceOf(user),
            executorBalanceAkro: await akro.balanceOf(callExecutor.address),
            executorBalanceAdel: await adel.balanceOf(callExecutor.address),
            executorRewardBalanceAkro: await stakingPool.rewardBalanceOf(callExecutor.address, akro.address),
            executorRewardBalanceAdel: await stakingPool.rewardBalanceOf(callExecutor.address, adel.address)
        }

        expect(after.userBalanceAkro).to.be.bignumber.eq(before.userBalanceAkro);
        expect(after.userBalanceAdel).to.be.bignumber.eq(before.userBalanceAdel);
        expect(after.executorBalanceAkro).to.be.bignumber.eq(before.executorBalanceAkro.add(before.executorRewardBalanceAkro).add(stakeAmount0));
        expect(after.executorBalanceAdel).to.be.bignumber.eq(before.executorBalanceAdel.add(before.executorRewardBalanceAdel));
        expect(after.executorRewardBalanceAkro).to.be.bignumber.eq(ZERO_BN);
        expect(after.executorRewardBalanceAdel).to.be.bignumber.eq(ZERO_BN);
    });

    async function addAllowanceAction(token:string, target:string, amount:BN) {
        let erc20 = new web3.eth.Contract((<any>FreeERC20).abi);
        let data = erc20.methods.approve(target, amount.toString()).encodeABI();
        await callExecutor.addCall(token, data, 0);
    }

    async function addStakeAction(amount:BN) {
        let data = stakingPoolContract.methods.stake(amount.toString(), ZERO_DATA).encodeABI();
        await callExecutor.addCall(stakingPool.address, data, 0);
    }

    async function addStakeForAction(user:string, amount:BN) {
        let data = stakingPoolContract.methods.stakeFor(user, amount.toString(), ZERO_DATA).encodeABI();
        await callExecutor.addCall(stakingPool.address, data, 0);
    }

    async function addUnstakeAction(amount:BN) {
        let data = stakingPoolContract.methods.unstake(amount.toString(), ZERO_DATA).encodeABI();
        await callExecutor.addCall(stakingPool.address, data, 0);
    }

    async function addUnstakeAllUnlockedAction() {
        let data = stakingPoolContract.methods.unstakeAllUnlocked(ZERO_DATA).encodeABI();
        await callExecutor.addCall(stakingPool.address, data, 0);
    }

    async function addWithdrawRewardsAction() {
        let data = stakingPoolContract.methods.withdrawRewards().encodeABI();
        await callExecutor.addCall(stakingPool.address, data, 0);
    }
});