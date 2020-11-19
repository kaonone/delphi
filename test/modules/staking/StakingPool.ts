import { 
    FreeErc20Contract,FreeErc20Instance,
    PoolContract, PoolInstance,
    RewardVestingModuleContract, RewardVestingModuleInstance,
    StakingPoolContract,StakingPoolInstance
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

contract("StakingPool", async ([owner, user, ...otherAccounts]) => {
    const ZERO_BN = new BN("0");
    const ZERO_DATA = "0x";
    const REWARD_EPOCH_DURATION = 24*60*60;

    let snap: Snapshot;
    let akro: FreeErc20Instance;
    let adel: FreeErc20Instance;
    let pool: PoolInstance;
    let rewardVestingModule: RewardVestingModuleInstance;
    let stakingPool: StakingPoolInstance;

    before(async () => {
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
    });

    it('should stake', async () => {
        let stakeAmount = w3random.interval(100, 500, 'ether');
        await akro.allocateTo(user, stakeAmount);

        const before = {
            userBalance: await akro.balanceOf(user),
            stakingPoolBalance: await akro.balanceOf(stakingPool.address),
            stakedTotal: await stakingPool.totalStakedFor(user),

        }

        await akro.approve(stakingPool.address, stakeAmount, {from:user});
        await stakingPool.stake(stakeAmount, ZERO_DATA, {from:user});

        const after = {
            userBalance: await akro.balanceOf(user),
            stakingPoolBalance: await akro.balanceOf(stakingPool.address),
            stakedTotal: await stakingPool.totalStakedFor(user),
        }

        expect(after.userBalance).to.be.bignumber.eq(before.userBalance.sub(stakeAmount));
        expect(after.stakingPoolBalance).to.be.bignumber.eq(before.stakingPoolBalance.add(stakeAmount));
        expect(after.stakedTotal).to.be.bignumber.eq(before.stakedTotal.add(stakeAmount));
    });

    it('should stake for another user', async () => {
        let stakeAmount = w3random.interval(100, 500, 'ether');
        await akro.allocateTo(user, stakeAmount);

        const before = {
            userBalance: await akro.balanceOf(user),
            stakingPoolBalance: await akro.balanceOf(stakingPool.address),
            stakedTotal: await stakingPool.totalStakedFor(otherAccounts[0]),
        }

        await akro.approve(stakingPool.address, stakeAmount, {from:user});
        await stakingPool.stakeFor(otherAccounts[0], stakeAmount, ZERO_DATA, {from:user});

        const after = {
            userBalance: await akro.balanceOf(user),
            stakingPoolBalance: await akro.balanceOf(stakingPool.address),
            stakedTotal: await stakingPool.totalStakedFor(otherAccounts[0]),
        }

        expect(after.userBalance).to.be.bignumber.eq(before.userBalance.sub(stakeAmount));
        expect(after.stakingPoolBalance).to.be.bignumber.eq(before.stakingPoolBalance.add(stakeAmount));
        expect(after.stakedTotal).to.be.bignumber.eq(before.stakedTotal.add(stakeAmount));
    });

    // //Partial unstake is not supported
    // it('should partially unstake own stake', async () => {
    //     const before = {
    //         userBalance: await akro.balanceOf(user),
    //         stakingPoolBalance: await akro.balanceOf(stakingPool.address),
    //         stakedTotal: await stakingPool.totalStakedFor(user),
    //     }
    //     let unstakeAmount = before.stakedTotal.divn(2);

    //     await stakingPool.unstake(unstakeAmount, ZERO_DATA, {from:user});

    //     const after = {
    //         userBalance: await akro.balanceOf(user),
    //         stakingPoolBalance: await akro.balanceOf(stakingPool.address),
    //         stakedTotal: await stakingPool.totalStakedFor(user),
    //     }

    //     expect(after.userBalance).to.be.bignumber.eq(before.userBalance.add(unstakeAmount));
    //     expect(after.stakingPoolBalance).to.be.bignumber.eq(before.stakingPoolBalance.sub(unstakeAmount));
    //     expect(after.stakedTotal).to.be.bignumber.eq(before.stakedTotal.sub(unstakeAmount));
    // });

    it('should fully unstake own stake', async () => {
        const before = {
            userBalance: await akro.balanceOf(user),
            stakingPoolBalance: await akro.balanceOf(stakingPool.address),
            stakedTotal: await stakingPool.totalStakedFor(user),
        }
        let unstakeAmount = before.stakedTotal;

        await stakingPool.unstakeAllUnlocked(ZERO_DATA, {from:user});

        const after = {
            userBalance: await akro.balanceOf(user),
            stakingPoolBalance: await akro.balanceOf(stakingPool.address),
            stakedTotal: await stakingPool.totalStakedFor(user),
        }

        expect(after.userBalance).to.be.bignumber.eq(before.userBalance.add(unstakeAmount));
        expect(after.stakingPoolBalance).to.be.bignumber.eq(before.stakingPoolBalance.sub(unstakeAmount));
        expect(after.stakedTotal).to.be.bignumber.eq(ZERO_BN);
    });

    it('should unstake stakedFor stake', async () => {
        const before = {
            userBalance: await akro.balanceOf(otherAccounts[0]),
            stakingPoolBalance: await akro.balanceOf(stakingPool.address),
            stakedTotal: await stakingPool.totalStakedFor(otherAccounts[0]),
        }

        await stakingPool.unstakeAllUnlocked(ZERO_DATA, {from:otherAccounts[0]});

        const after = {
            userBalance: await akro.balanceOf(otherAccounts[0]),
            stakingPoolBalance: await akro.balanceOf(stakingPool.address),
            stakedTotal: await stakingPool.totalStakedFor(otherAccounts[0]),
        }

        expect(after.userBalance).to.be.bignumber.eq(before.userBalance.add(before.stakedTotal));
        expect(after.stakingPoolBalance).to.be.bignumber.eq(before.stakingPoolBalance.sub(before.stakedTotal));
        expect(after.stakedTotal).to.be.bignumber.eq(ZERO_BN);
    });

    it('should receive rewards when staking for yourself', async () => {
        let stakeAmount = w3random.interval(100, 500, 'ether');
        await akro.allocateTo(user, stakeAmount);


        await akro.approve(stakingPool.address, stakeAmount, {from:user});
        await stakingPool.stake(stakeAmount, ZERO_DATA, {from:user});

        const before = {
            userBalanceAkro: await akro.balanceOf(user),
            userBalanceAdel: await adel.balanceOf(user),
            stakedTotal: await stakingPool.totalStakedFor(user),
        }

        await time.increase(REWARD_EPOCH_DURATION);
        await stakingPool.claimRewardsFromVesting();

        await stakingPool.withdrawRewards({from:user});

        const afterWR = {
            userBalanceAkro: await akro.balanceOf(user),
            userBalanceAdel: await adel.balanceOf(user),
            stakedTotal: await stakingPool.totalStakedFor(user),
        }

        expect(afterWR.userBalanceAkro).to.be.bignumber.gt(before.userBalanceAkro);
        expect(afterWR.userBalanceAdel).to.be.bignumber.gt(before.userBalanceAdel);
        expect(afterWR.stakedTotal).to.be.bignumber.eq(before.stakedTotal);

        await stakingPool.unstakeAllUnlocked(ZERO_DATA, {from:user});

        const afterU = {
            userBalanceAkro: await akro.balanceOf(user),
            userBalanceAdel: await adel.balanceOf(user),
            stakedTotal: await stakingPool.totalStakedFor(user),
        }

        expect(afterU.userBalanceAkro).to.be.bignumber.gt(afterWR.userBalanceAkro.add(stakeAmount));
        expect(afterU.userBalanceAdel).to.be.bignumber.eq(afterWR.userBalanceAdel);
        expect(afterU.stakedTotal).to.be.bignumber.eq(ZERO_BN);
    });

    it('should receive rewards when staking for another user', async () => {
        let stakeAmount = w3random.interval(100, 500, 'ether');
        await akro.allocateTo(user, stakeAmount);


        await akro.approve(stakingPool.address, stakeAmount, {from:user});
        await stakingPool.stakeFor(otherAccounts[0], stakeAmount, ZERO_DATA, {from:user});

        const before = {
            userBalanceAkro: await akro.balanceOf(otherAccounts[0]),
            userBalanceAdel: await adel.balanceOf(otherAccounts[0]),
            stakedTotal: await stakingPool.totalStakedFor(otherAccounts[0]),
        }

        await time.increase(REWARD_EPOCH_DURATION);
        await stakingPool.claimRewardsFromVesting();

        await stakingPool.withdrawRewards({from:otherAccounts[0]});

        const afterWR = {
            userBalanceAkro: await akro.balanceOf(otherAccounts[0]),
            userBalanceAdel: await adel.balanceOf(otherAccounts[0]),
            stakedTotal: await stakingPool.totalStakedFor(otherAccounts[0]),
        }

        expect(afterWR.userBalanceAkro).to.be.bignumber.gt(before.userBalanceAkro);
        expect(afterWR.userBalanceAdel).to.be.bignumber.gt(before.userBalanceAdel);
        expect(afterWR.stakedTotal).to.be.bignumber.eq(before.stakedTotal);

        await stakingPool.unstakeAllUnlocked(ZERO_DATA, {from:otherAccounts[0]});

        const afterU = {
            userBalanceAkro: await akro.balanceOf(otherAccounts[0]),
            userBalanceAdel: await adel.balanceOf(otherAccounts[0]),
            stakedTotal: await stakingPool.totalStakedFor(otherAccounts[0]),
        }

        expect(afterU.userBalanceAkro).to.be.bignumber.gt(afterWR.userBalanceAkro.add(stakeAmount));
        expect(afterU.userBalanceAdel).to.be.bignumber.eq(afterWR.userBalanceAdel);
        expect(afterU.stakedTotal).to.be.bignumber.eq(ZERO_BN);
    });

});