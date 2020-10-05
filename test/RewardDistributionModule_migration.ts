const { BN, constants, expectEvent, shouldFail, time } = require("@openzeppelin/test-helpers");
const { deployProxy, upgradeProxy } = require('@openzeppelin/truffle-upgrades');

import Snapshot from "./utils/snapshot";
const should = require("chai").should();
var expect = require("chai").expect;
const expectRevert= require("./utils/expectRevert");
const expectEqualBN = require("./utils/expectEqualBN");
const w3random = require("./utils/w3random");

const FreeERC20 = artifacts.require("FreeERC20");
const CErc20Stub = artifacts.require("CErc20Stub");
const ComptrollerStub = artifacts.require("ComptrollerStub");

const Pool = artifacts.require("Pool");
const AccessModule = artifacts.require("AccessModule");
const SavingsModule = artifacts.require("SavingsModule");
const SavingsModuleOld = artifacts.require("SavingsModuleOld");
const RewardDistributionModule = artifacts.require("RewardDistributionModule");
const CompoundProtocol = artifacts.require("CompoundProtocol");
const PoolToken = artifacts.require("PoolToken");
const StakingPool  =  artifacts.require("StakingPool");
const StakingPoolADEL  =  artifacts.require("StakingPoolADEL");

contract("RewardDistributionModule - migration", async ([owner, user, ...otherAccounts]) => {
    let snap;

    let dai;
    let cDai;
    let comp;
    let comptroller;


    let pool;
    let access;
    let savings;
    let rewardDistributions;
    let compoundProtocolDai;
    let poolTokenCompoundProtocolDai;    
    let akro;
    let adel;
    let stakingPoolAkro;
    let stakingPoolAdel;


    before(async () => {
        //Setup external contracts
        dai = await deployProxy(FreeERC20, ["Dai Stablecoin", "DAI"]);
        cDai = await deployProxy(CErc20Stub, [dai.address]);
        comp = await deployProxy(FreeERC20, ["Compound", "COMP"]);
        comptroller = await deployProxy(ComptrollerStub, [comp.address]);
        await comp.methods['mint(address,uint256)'](comptroller.address, web3.utils.fromWei(1000000000));

        //Setup system contracts
        pool = await deployProxy(Pool, []);

        access = await deployProxy(AccessModule, [pool.address]);
        await pool.set('access', access.address, false);

        savings = await deployProxy(SavingsModuleOld, [pool.address]);
        await pool.set('savings', savings.address, false);

        akro = await deployProxy(FreeERC20, ["Akropolis", "AKRO"]);
        await pool.set('akro', akro.address, false);
        adel = await deployProxy(FreeERC20, ["Akropolis Delphi", "ADEL"]);
        await pool.set('adel', adel.address, false);

        stakingPoolAkro = await deployProxy(StakingPool, [pool.address, akro.address, '0']);
        await pool.set('staking', stakingPoolAkro.address, false);
        stakingPoolAdel = await deployProxy(StakingPoolADEL, [pool.address, adel.address, '0']);
        await pool.set('stakingAdel', stakingPoolAdel.address, false);

        compoundProtocolDai = await deployProxy(CompoundProtocol, [pool.address, dai.address, cDai.address, comptroller.address]);
        poolTokenCompoundProtocolDai = await deployProxy(PoolToken, [pool.address, "Delphi Compound DAI","dCDAI"]);
        await savings.registerProtocol(compoundProtocolDai, poolTokenCompoundProtocolDai);

        rewardDistributions = await deployProxy(RewardDistributionModule, [pool.address]);
        await pool.set('rewardDistributions', rewardDistributions.address, false);
        await rewardDistributions.registerProtocol(compoundProtocolDai, poolTokenCompoundProtocolDai);


        //Save snapshot
        snap = await Snapshot.create(web3.currentProvider);
    });

    beforeEach(async () => {
        //await snap.revert();
    });

    it('should deposit', async () => {
        let amount = web3.utils.fromWei(1000);
        await dai.methods['mint(address,uint256)'](user, amount);
        await dai.approve(savings.address, amount);
        await savings.methods['deposit(address,address[],uint256[])'](compoundProtocol.address, [dai.address], [amount]);

        let lpAmount = poolTokenCompoundProtocolDai.balanceOf(user);
        expect(lpAmount).to.be.bignumber.gt(0);
    });

    it('should receive rewards', async () => {
        await time.increase(7*24*60*60);
        await savings.distributeRewards();

        let userReward = await savings.rewardBalanceOf(user, poolTokenCompoundProtocolDai.address, comp.address);
        expect(userReward).to.be.bignumber.gt(0); 
    });

    it('should upgrade savings', async () => {
        savings = await upgradeProxy(savings.address, SavingsModule);
    });        

    it('should still have rewards', async () => {
        let userReward = await rewardDistributions.rewardBalanceOf(user, poolTokenCompoundProtocolDai.address, comp.address);
        expect(userReward).to.be.bignumber.gt(0); 
    });

    it('should withdraw rewards', async () => {
        await rewardDistributions.withdrawReward({from:user});
        let userReward = await comp.balanceOf(user);
        expect(userReward).to.be.bignumber.gt(0); 
    });

});



