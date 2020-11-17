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

        await stakingPool.registerRewardToken(akro.address);
        await stakingPool.registerRewardToken(adel.address);


        //Prepare liquidity
        await akro.methods['mint(address,uint256)'](owner, web3.utils.toWei('1000000000'));
        await adel.methods['mint(address,uint256)'](owner, web3.utils.toWei('1000000000'));

        //Save snapshot
        //snap = await Snapshot.create(web3.currentProvider);
    });

    it('should stake', async () => {
        let stakeAmount = w3random.interval(100, 500, 'ether');
        await akro.allocateTo(user, stakeAmount);

        const before = {
            userBalance: await akro.balanceOf(user),
            stakingPoolBalance: await akro.balanceOf(stakingPool.address),

        }

        await akro.approve(stakingPool.address, stakeAmount, {from:user});
        await stakingPool.stake(stakeAmount, "0x", {from:user});

        const after = {
            userBalance: await akro.balanceOf(user),
            stakingPoolBalance: await akro.balanceOf(stakingPool.address),

        }

        expect(after.userBalance).to.be.bignumber.eq(before.userBalance.sub(stakeAmount));
        expect(after.stakingPoolBalance).to.be.bignumber.eq(before.stakingPoolBalance.add(stakeAmount));
    });

});