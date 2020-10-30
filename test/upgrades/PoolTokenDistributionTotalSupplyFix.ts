import { 
    PoolContract, PoolInstance, 
    AccessModuleContract, AccessModuleInstance,
    SavingsModuleContract, SavingsModuleInstance,
    RewardDistributionModuleContract,RewardDistributionModuleInstance,
    RewardVestingModuleContract, RewardVestingModuleInstance,
    PoolTokenContract,PoolTokenInstance,
    PoolTokenOld2Contract,PoolTokenOld2Instance,
    StakingPoolContract,StakingPoolInstance,
    StakingPoolAdelContract,StakingPoolAdelInstance,
    CompoundProtocolContract,CompoundProtocolInstance,
    FreeErc20Contract,FreeErc20Instance,
    CErc20StubContract, CErc20StubInstance
} from "../../types/truffle-contracts/index";


const { BN, constants, expectEvent, shouldFail, time } = require("@openzeppelin/test-helpers");

const { deployProxy, upgradeProxy } = require('@openzeppelin/truffle-upgrades');
const UPGRADABLE_OPTS = {
    unsafeAllowCustomTypes: true
};

import Snapshot from "../utils/snapshot";
const should = require("chai").should();
var expect = require("chai").expect;
const expectRevert= require("../utils/expectRevert");
const expectEqualBN = require("../utils/expectEqualBN");
const w3random = require("../utils/w3random");

const FreeERC20 = artifacts.require("FreeERC20");
const CErc20Stub = artifacts.require("CErc20Stub");
const ComptrollerStub = artifacts.require("ComptrollerStub");

const Pool = artifacts.require("Pool");
const AccessModule = artifacts.require("AccessModule");
const SavingsModule = artifacts.require("SavingsModule");
const RewardVestingModule = artifacts.require("RewardVestingModule");
const RewardDistributionModule = artifacts.require("RewardDistributionModule");
const CompoundProtocol = artifacts.require("CompoundProtocol");
const PoolToken = artifacts.require("PoolToken");
const PoolTokenOld2 = artifacts.require("PoolTokenOld2");

const StakingPool  =  artifacts.require("StakingPool");
const StakingPoolADEL  =  artifacts.require("StakingPoolADEL");

contract("Upgrades: PoolToken Distribution Total Supply fix", async ([owner, user, ...otherAccounts]) => {
    //let snap:Snapshot;

    let dai:FreeErc20Instance;
    let cDai:CErc20StubInstance;
    let comp:FreeErc20Instance;

    let pool:PoolInstance;
    let access:AccessModuleInstance;
    let savings:SavingsModuleInstance;
    let rewardDistributions:RewardDistributionModuleInstance;
    let rewardVesting:RewardVestingModuleInstance;
    let compoundProtocolDai:CompoundProtocolInstance;
    let dCDAI:PoolTokenOld2Instance|PoolTokenInstance;    
    let akro:FreeErc20Instance;
    let adel:FreeErc20Instance;
    let stakingPoolAkro:StakingPoolInstance;
    let stakingPoolAdel:StakingPoolAdelInstance;


    before(async () => {
        //Setup external contracts
        dai = await deployProxy(FreeERC20, ["Dai Stablecoin", "DAI"], UPGRADABLE_OPTS);
        cDai = await deployProxy(CErc20Stub, [dai.address], UPGRADABLE_OPTS);
        comp = await deployProxy(FreeERC20, ["Compound", "COMP"], UPGRADABLE_OPTS);

        let comptroller = await deployProxy(ComptrollerStub, [comp.address], UPGRADABLE_OPTS);


        //Setup system contracts
        pool = await deployProxy(Pool, [], UPGRADABLE_OPTS);

        access = await deployProxy(AccessModule, [pool.address], UPGRADABLE_OPTS);
        await pool.set('access', access.address, false);

        savings = await deployProxy(SavingsModule, [pool.address], UPGRADABLE_OPTS);
        await pool.set('savings', savings.address, false);

        akro = await deployProxy(FreeERC20, ["Akropolis", "AKRO"], UPGRADABLE_OPTS);
        await pool.set('akro', akro.address, false);
        adel = await deployProxy(FreeERC20, ["Akropolis Delphi", "ADEL"], UPGRADABLE_OPTS);
        await pool.set('adel', adel.address, false);

        stakingPoolAkro = await deployProxy(StakingPool, [pool.address, akro.address, '0'], UPGRADABLE_OPTS);
        await pool.set('staking', stakingPoolAkro.address, false);
        stakingPoolAdel = await deployProxy(StakingPoolADEL, [pool.address, adel.address, '0'], UPGRADABLE_OPTS);
        await pool.set('stakingAdel', stakingPoolAdel.address, false);

        compoundProtocolDai = await deployProxy(CompoundProtocol, [pool.address, dai.address, cDai.address, comptroller.address], UPGRADABLE_OPTS);
        dCDAI = await deployProxy(PoolTokenOld2, [pool.address, "Delphi Compound DAI","dCDAI"], UPGRADABLE_OPTS);
        await savings.registerProtocol(compoundProtocolDai.address, dCDAI.address);
        await compoundProtocolDai.addDefiOperator(savings.address);
        await dCDAI.addMinter(savings.address);

        rewardVesting = await deployProxy(RewardVestingModule, [pool.address], UPGRADABLE_OPTS);
        await pool.set('reward', rewardVesting.address, false);

        rewardDistributions = await deployProxy(RewardDistributionModule, [pool.address], UPGRADABLE_OPTS);
        await pool.set('rewardDistributions', rewardDistributions.address, false);
        await rewardDistributions.registerProtocol(compoundProtocolDai.address, dCDAI.address);
        await compoundProtocolDai.addDefiOperator(rewardDistributions.address);

        //Save snapshot
        //snap = await Snapshot.create(web3.currentProvider);

    });

    beforeEach(async () => {
        //await snap.revert();
    });

    it('should make deposits', async () => {
        for(let i = 0; i < otherAccounts.length; i++) {
            let amount = w3random.interval(100, 10000, 'ether');
            await dai.allocateTo(otherAccounts[i], amount);
            await dai.approve(savings.address, amount, {from:otherAccounts[i]});

            await savings.methods['deposit(address,address[],uint256[])'](compoundProtocolDai.address, [dai.address], [amount], {from:otherAccounts[i]});
            let ptBalance = await dCDAI.balanceOf(otherAccounts[i]);
            expectEqualBN(ptBalance, amount, 18, -1); //may take some fee
        }
        let totalSupply = await dCDAI.totalSupply();
        let pnBalance = await compoundProtocolDai.normalizedBalance.call();
        console.log("pnBalance, totalSupply", pnBalance.toString(), totalSupply.toString());
        expect(pnBalance).to.be.bignumber.gte(totalSupply);
    });

    it('should create first distribution', async () => {
        await time.increase(7*24*60*60);

        let totalSupply = await dCDAI.totalSupply();
        let pnBalance = await compoundProtocolDai.normalizedBalance.call();
        console.log("pnBalance, totalSupply", pnBalance.toString(), totalSupply.toString());
        expect(pnBalance).to.be.bignumber.gte(totalSupply);

        const before = {
            totalSupply: await dCDAI.totalSupply()
        }
        await savings.distributeYield();

        const after = {
            totalSupply: await dCDAI.totalSupply()
        }
        expect(after.totalSupply).to.be.bignumber.gt(before.totalSupply);

        totalSupply = await dCDAI.totalSupply();
        pnBalance = await compoundProtocolDai.normalizedBalance.call();
        console.log("pnBalance, totalSupply", pnBalance.toString(), totalSupply.toString());
        expect(pnBalance).to.be.bignumber.gte(totalSupply);
    });

    it('should do claim yield for some users', async () => {
        let someoneClaimed;
        for(let i = 0; i < otherAccounts.length-1; i++) {
            let doClaim = (Math.random() > 0.5);
            if(doClaim){
                someoneClaimed = true;
                await dCDAI.methods['claimDistributions(address)'](otherAccounts[i]);
            }
        }
        if(!someoneClaimed){
            await dCDAI.methods['claimDistributions(address)'](otherAccounts[otherAccounts.length-1]);
        } // else leave account 9 not claimed

        let totalSupply = await dCDAI.totalSupply();
        let pnBalance = await compoundProtocolDai.normalizedBalance.call();
        console.log("pnBalance, totalSupply", pnBalance.toString(), totalSupply.toString());
        expect(pnBalance).to.be.bignumber.gte(totalSupply);
    });

    it('should create second distribution', async () => {
        await time.increase(7*24*60*60);
        const before = {
            totalSupply: await dCDAI.totalSupply()
        }
        await savings.distributeYield();

        const after = {
            totalSupply: await dCDAI.totalSupply()
        }
        expect(after.totalSupply).to.be.bignumber.gt(before.totalSupply);

        let totalSupply = await dCDAI.totalSupply();
        let pnBalance = await compoundProtocolDai.normalizedBalance.call();
        console.log("pnBalance, totalSupply", pnBalance.toString(), totalSupply.toString());
        expect(pnBalance).to.be.bignumber.gte(totalSupply);
    });

    it('should have totalSupply less than fullBalance of all users', async () => {
        let summFullBalance = await countFullBalanceOfUsers(otherAccounts);
        let totalSupply = await dCDAI.totalSupply();
        expect(totalSupply).to.be.bignumber.lt(summFullBalance);

        let pnBalance = await compoundProtocolDai.normalizedBalance.call();
        console.log("pnBalance, totalSupply", pnBalance.toString(), totalSupply.toString());
        expect(pnBalance).to.be.bignumber.gte(totalSupply);
    });

    it('should fix totalSupply and balances', async () => {
        let summFullBalance = await countFullBalanceOfUsers(otherAccounts);
        let totalSupply = await dCDAI.totalSupply();
        let accumulator = await dCDAI.distributionAccumulator();
        console.log('accumulator', accumulator.toString());
        let diff = summFullBalance.sub(totalSupply).sub(accumulator);
        expect(diff).to.be.bignumber.gt("0");
        console.log('diff',diff.toString());

        let fixAmount = diff.muln(105).divn(100); //Add additional anount for possible fees

        await dai.allocateTo(owner, fixAmount);
        await dai.approve(savings.address, fixAmount);

        dCDAI = await upgradeProxy(dCDAI.address, PoolToken, UPGRADABLE_OPTS);

        totalSupply = await dCDAI.totalSupply();
        let pnBalance = await compoundProtocolDai.normalizedBalance.call();
        console.log("1 pnBalance, totalSupply", pnBalance.toString(), totalSupply.toString());

        await savings.methods['deposit(address,address[],uint256[])'](compoundProtocolDai.address,[dai.address], [fixAmount]);

        // let nd = await dCDAI.nextDistributions(owner);
        // console.log(nd);

        accumulator = await dCDAI.distributionAccumulator();
        console.log('accumulator 2', accumulator.toString());

        totalSupply = await dCDAI.totalSupply();
        pnBalance = await compoundProtocolDai.normalizedBalance.call();
        console.log("2 pnBalance, totalSupply", pnBalance.toString(), totalSupply.toString());

        let fbo = await dCDAI.fullBalanceOf(owner);
        console.log('fbo', fbo.toString());
        await dCDAI.burnFrom(owner, diff);

        totalSupply = await dCDAI.totalSupply();
        pnBalance = await compoundProtocolDai.normalizedBalance.call();
        console.log("4 pnBalance, totalSupply", pnBalance.toString(), totalSupply.toString());

        await dCDAI.mint(dCDAI.address, diff);

        totalSupply = await dCDAI.totalSupply();
        pnBalance = await compoundProtocolDai.normalizedBalance.call();
        console.log("5 pnBalance, totalSupply", pnBalance.toString(), totalSupply.toString());

        await time.increase(7*24*60*60);
        await savings.distributeYield();
        //await dCDAI.createDistribution();


        totalSupply = await dCDAI.totalSupply();
        pnBalance = await compoundProtocolDai.normalizedBalance.call();
        console.log("pnBalance, totalSupply", pnBalance.toString(), totalSupply.toString());
        expect(pnBalance).to.be.bignumber.gte(totalSupply);
    });

    it('should have totalSupply equal to fullBalance of all users', async () => {
        let withdrawAccounts = otherAccounts.concat(owner);
        let summFullBalance = await countFullBalanceOfUsers(withdrawAccounts);
        let totalSupply = await dCDAI.totalSupply();
        expectEqualBN(totalSupply, summFullBalance, 18, -17);
        let pnBalance = await compoundProtocolDai.normalizedBalance.call();
        expect(pnBalance).to.be.bignumber.gte(totalSupply);
    });

    it('should allow full withdraw for all', async () => {
        let withdrawAccounts = otherAccounts.concat(owner);
        for(let i = 0; i < withdrawAccounts.length ; i++) {
            let fullBalance = await dCDAI.fullBalanceOf(withdrawAccounts[i]);
            let totalSupply = await dCDAI.totalSupply();
            let pnBalance = await compoundProtocolDai.normalizedBalance.call();

            console.log('i', i, fullBalance.toString(), totalSupply.toString(), pnBalance.toString());
            //await dCDAI.methods['claimDistributions(address)'](withdrawAccounts[i]);
            await savings.withdraw(compoundProtocolDai.address, dai.address, fullBalance, "0", {from:withdrawAccounts[i]});
            let daiBalance = await dai.balanceOf(withdrawAccounts[i]);
            //expect(daiBalance).to.be.bignumber.gte(fullBalance);
        }
    });



    async function countFullBalanceOfUsers(users:Array<string>){
        let summFullBalance = new BN("0");
        for(let i = 0; i < users.length; i++) {
            let fb = await dCDAI.fullBalanceOf(users[i]);
            summFullBalance = summFullBalance.add(fb);
        }
        return summFullBalance;
    }
});
