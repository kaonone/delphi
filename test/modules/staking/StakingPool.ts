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
    const LOCK_DURATION = 2*60*60;

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

        // console.log('user', user);
        // console.log('otherAccounts[0]', otherAccounts[0]);

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
        //console.log('stakeAmount', stakeAmount.toString());
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

    it('should fully unstake all stakes', async () => {
        const before = {
            userBalance: await akro.balanceOf(user),
            stakingPoolBalance: await akro.balanceOf(stakingPool.address),
            stakedTotal: await stakingPool.getPersonalStakeTotalAmount(user),
            stakedForTotal: await stakingPool.totalStakedFor(otherAccounts[0])
        }
        expect(before.stakedForTotal).to.be.bignumber.gt(ZERO_BN);

        await stakingPool.unstakeAllUnlocked(ZERO_DATA, {from:user});

        const after = {
            userBalance: await akro.balanceOf(user),
            stakingPoolBalance: await akro.balanceOf(stakingPool.address),
            stakedTotal: await stakingPool.totalStakedFor(user),
            stakedForTotal: await stakingPool.totalStakedFor(otherAccounts[0])
        }

        expect(after.userBalance).to.be.bignumber.eq(before.userBalance.add(before.stakedTotal));
        expect(after.stakedForTotal).to.be.bignumber.eq(ZERO_BN);
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

        expect(afterU.userBalanceAkro).to.be.bignumber.eq(afterWR.userBalanceAkro.add(stakeAmount));
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

    });

    it('should set stakingCap and allow stake within it', async () => {
        let stakingCap = w3random.interval(5000, 8000, 'ether');

        await stakingPool.setStakingCap(stakingCap);
        await stakingPool.setStakingCapEnabled(true);
        await stakingPool.setVipUserEnabled(true);

        let stakeAmount = stakingCap.divn(2)
        await akro.allocateTo(user, stakeAmount);

        const before = {
            stakingPoolBalance: await akro.balanceOf(stakingPool.address),
        }

        await akro.approve(stakingPool.address, stakeAmount, {from:user});
        await stakingPool.stake(stakeAmount, ZERO_DATA, {from:user});

        const after = {
            stakingPoolBalance: await akro.balanceOf(stakingPool.address),
        }
    });

    it('should deny stake exeeds staking cap', async () => {
        let stakingCap = await stakingPool.stakingCap();

        const before = {
            stakingPoolBalance: await akro.balanceOf(stakingPool.address),
        }

        // stake almost to limit
        let stakeAmount = stakingCap.sub(before.stakingPoolBalance).subn(1);
        await akro.allocateTo(otherAccounts[0], stakeAmount);
        await akro.approve(stakingPool.address, stakeAmount, {from:otherAccounts[0]});
        await stakingPool.stake(stakeAmount, ZERO_DATA, {from:otherAccounts[0]});

        const after = {
            stakingPoolBalance: await akro.balanceOf(stakingPool.address),
        }
        expect(after.stakingPoolBalance).to.be.bignumber.eq(stakingCap.subn(1));

        stakeAmount = w3random.interval(100, 200, 'ether');
        await akro.allocateTo(user, stakeAmount);
        await akro.approve(stakingPool.address, stakeAmount, {from:user});

        await expectRevert(
            stakingPool.stake(stakeAmount, ZERO_DATA, {from:user}),
            "StakingModule: stake exeeds staking cap"
        );
    });

    it('should allow stake for VIP user', async () => {
        let stakeAmount = w3random.interval(100, 200, 'ether');
        await akro.allocateTo(user, stakeAmount);
        await akro.approve(stakingPool.address, stakeAmount, {from:user});

        await stakingPool.setVipUser(user, true);
        await stakingPool.stake(stakeAmount, ZERO_DATA, {from:user});
    });

    it('should unstake for VIP user', async () => {
        await stakingPool.unstakeAllUnlocked(ZERO_DATA, {from:user});
    });

    it('should set default userCap and allow stake within it', async () => {
        let userCap = w3random.interval(500, 1000, 'ether');
        await stakingPool.setDefaultUserCap(userCap);
        await stakingPool.setUserCapEnabled(true);
        await stakingPool.setVipUserEnabled(true);

        let stakeAmount = userCap.subn(1)
        await akro.allocateTo(otherAccounts[2], stakeAmount);
        await akro.approve(stakingPool.address, stakeAmount, {from:otherAccounts[2]});
        await stakingPool.stake(stakeAmount, ZERO_DATA, {from:otherAccounts[2]});

        stakeAmount = userCap.addn(1)
        await akro.allocateTo(otherAccounts[3], stakeAmount);
        await akro.approve(stakingPool.address, stakeAmount, {from:otherAccounts[3]});
        await expectRevert(
            stakingPool.stake(stakeAmount, ZERO_DATA, {from:otherAccounts[3]}),
            "StakingModule: stake exeeds cap"
        );
        await stakingPool.setUserCapEnabled(false);
    });


    it('should set lock duration', async () => {
        await stakingPool.setDefaultLockInDuration(LOCK_DURATION);
    });
    it('should stake', async () => {
        let stakeAmount = w3random.interval(100, 500, 'ether');
        await akro.allocateTo(user, stakeAmount);
        await akro.approve(stakingPool.address, stakeAmount, {from:user});
        await stakingPool.stake(stakeAmount, ZERO_DATA, {from:user});
    });

    it('should not unstake befor lock ends', async () => {
        const before = {
            userBalance: await akro.balanceOf(user),
        }

        await stakingPool.unstakeAllUnlocked(ZERO_DATA, {from:user});

        const after = {
            userBalance: await akro.balanceOf(user),
        }

        expect(after.userBalance).to.be.bignumber.eq(before.userBalance);


        let stakes = await stakingPool.getPersonalStakeActualAmounts(user);
        expect(stakes.length).to.be.eq(1);

        await expectRevert(
            stakingPool.unstake(stakes[0], ZERO_DATA, {from:user}),
            "The current stake hasn't unlocked yet"
        );
    });

    it('should unstake after lock ends', async () => {
        time.increase(LOCK_DURATION);

        let stakes = await stakingPool.getPersonalStakeActualAmounts(user);
        expect(stakes.length).to.be.eq(1);

        await stakingPool.unstake(stakes[0], ZERO_DATA, {from:user});

        let stakedFor = await stakingPool.totalStakedFor(user);
        let stakesTotal = await stakingPool.getPersonalStakeTotalAmount(user);
        expect(stakedFor).to.be.bignumber.eq(ZERO_BN);
        expect(stakesTotal).to.be.bignumber.eq(ZERO_BN);
    });


    it('should correctly unstake unlocked', async () => {
        let allStakesAmount = new BN(web3.utils.toWei('1000'));
        let stakeAmount = allStakesAmount.divn(10);
        await akro.allocateTo(user, allStakesAmount);
        await akro.approve(stakingPool.address, allStakesAmount, {from:user});

        for(let i=0; i<10; i++) {
            await stakingPool.stake(stakeAmount, ZERO_DATA, {from:user});
            time.increase(Math.ceil(LOCK_DURATION/10));
        }

        let balance = await akro.balanceOf(user);
        for(let i=0; i<10; i++) {
            let skip = (Math.random() > 0.3);
            if(!skip) {
                await stakingPool.unstakeAllUnlocked(ZERO_DATA, {from:user});
                let newBalance = await akro.balanceOf(user);
                expectEqualBN(newBalance, balance.add(stakeAmount.muln(i+1)));
            }

            time.increase(Math.ceil(LOCK_DURATION/10));
        }
    });

});