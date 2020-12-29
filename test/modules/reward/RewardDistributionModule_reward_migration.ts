import { 
    PoolContract, PoolInstance, 
    AccessModuleContract, AccessModuleInstance,
    SavingsModuleContract, SavingsModuleInstance,
    SavingsModuleOldContract,SavingsModuleOldInstance,
    RewardDistributionModuleContract,RewardDistributionModuleInstance,
    RewardVestingModuleContract, RewardVestingModuleInstance,
    CompoundProtocolContract,CompoundProtocolInstance,
    PoolTokenContract,PoolTokenInstance,
    StakingPoolContract,StakingPoolInstance,
    StakingPoolADELContract,StakingPoolADELInstance,
    FreeERC20Contract,FreeERC20Instance,
    CErc20StubContract,CErc20StubInstance,
    ComptrollerStubContract,ComptrollerStubInstance
} from "../../../types/truffle-contracts/index";


const { BN, constants, expectEvent, shouldFail, time } = require("@openzeppelin/test-helpers");
const { deployProxy, upgradeProxy } = require('@openzeppelin/truffle-upgrades');
const UPGRADABLE_OPTS = {
    unsafeAllowCustomTypes: true
};

import Snapshot from "./../../utils/snapshot";
const should = require("chai").should();
var expect = require("chai").expect;
const expectRevert= require("./../../utils/expectRevert");
const expectEqualBN = require("./../../utils/expectEqualBN");
const w3random = require("./../../utils/w3random");

const FreeERC20 = artifacts.require("FreeERC20");
const CErc20Stub = artifacts.require("CErc20Stub");
const ComptrollerStub = artifacts.require("ComptrollerStub");

const Pool = artifacts.require("Pool");
const AccessModule = artifacts.require("AccessModule");
const SavingsModule = artifacts.require("SavingsModule");
const SavingsModuleOld = artifacts.require("SavingsModuleOld");
const RewardVestingModule = artifacts.require("RewardVestingModule");
const RewardDistributionModule = artifacts.require("RewardDistributionModule");
const CompoundProtocol = artifacts.require("CompoundProtocol");
const PoolToken = artifacts.require("PoolToken");

const StakingPool  =  artifacts.require("StakingPool");
const StakingPoolADEL  =  artifacts.require("StakingPoolADEL");

contract("RewardDistributionModule - reward migration", async ([owner, user, ...otherAccounts]) => {
    //let snap:Snapshot;

    let dai:FreeERC20Instance;
    let cDai:CErc20StubInstance;
    let comp:FreeERC20Instance;
    let comptroller:ComptrollerStubInstance;


    let pool:PoolInstance;
    let access:AccessModuleInstance;
    let savings:SavingsModuleOldInstance|SavingsModuleInstance;
    let rewardDistributions:RewardDistributionModuleInstance;
    let rewardVesting:RewardVestingModuleInstance;
    let compoundProtocolDai:CompoundProtocolInstance;
    let poolTokenCompoundProtocolDai:PoolTokenInstance;    
    let akro:FreeERC20Instance;
    let adel:FreeERC20Instance;
    let stakingPoolAkro:StakingPoolInstance;
    let stakingPoolAdel:StakingPoolADELInstance;


    before(async () => {
        //Setup external contracts
        dai = await FreeERC20.new();
        await dai.methods['initialize(string,string,uint8)']("Dai Stablecoin", "DAI", 18);
        cDai = await CErc20Stub.new();
        await cDai.methods['initialize(address)'](dai.address);
        comp = await FreeERC20.new();
        await comp.methods['initialize(string,string,uint8)']("Compound", "COMP", 18);
        comptroller = await ComptrollerStub.new();
        await comptroller.methods['initialize(address)'](comp.address);


        await comptroller.setSupportedCTokens([cDai.address]);
        await comp.methods['mint(address,uint256)'](comptroller.address, web3.utils.toWei('1000000000'));

        //Setup system contracts
        pool = await Pool.new();
        await pool.methods['initialize()']();
        access = await AccessModule.new();
        await access.methods['initialize(address)'](pool.address);
        await pool.set('access', access.address, false);

        // savings = await SavingsModule.new();
        // await savings.methods['initialize(address)'](pool.address);
        savings = await deployProxy(SavingsModuleOld, [pool.address], UPGRADABLE_OPTS);
        await pool.set('savings', savings.address, false);

        akro = await FreeERC20.new();
        await akro.methods['initialize(string,string)']("Akropolis", "AKRO");
        await pool.set('akro', akro.address, false);
        adel = await FreeERC20.new();
        await adel.methods['initialize(string,string)']("Akropolis Delphi", "ADEL");
        await pool.set('adel', adel.address, false);

        stakingPoolAkro = await StakingPool.new();
        await stakingPoolAkro.methods['initialize(address,address,uint256)'](pool.address, akro.address, '0');
        await pool.set('staking', stakingPoolAkro.address, false);
        stakingPoolAdel = await StakingPoolADEL.new();
        await stakingPoolAdel.methods['initialize(address,address,uint256)'](pool.address, adel.address, '0');
        await pool.set('stakingAdel', stakingPoolAdel.address, false);

        compoundProtocolDai = await CompoundProtocol.new();
        await compoundProtocolDai.methods['initialize(address,address,address,address)'](pool.address, dai.address, cDai.address, comptroller.address);
        poolTokenCompoundProtocolDai = await PoolToken.new();
        await poolTokenCompoundProtocolDai.methods['initialize(address,string,string)'](pool.address, "Delphi Compound DAI","dCDAI");
        await savings.registerProtocol(compoundProtocolDai.address, poolTokenCompoundProtocolDai.address);
        await compoundProtocolDai.addDefiOperator(savings.address);
        await poolTokenCompoundProtocolDai.addMinter(savings.address);

        rewardVesting = await RewardVestingModule.new();
        await rewardVesting.methods['initialize(address)'](pool.address);
        await pool.set('reward', rewardVesting.address, false);

        rewardDistributions = await RewardDistributionModule.new();
        await rewardDistributions.methods['initialize(address)'](pool.address);
        await pool.set('rewardDistributions', rewardDistributions.address, false);
        await rewardDistributions.registerProtocol(compoundProtocolDai.address, poolTokenCompoundProtocolDai.address);
        await compoundProtocolDai.addDefiOperator(rewardDistributions.address);

        //Save snapshot
        //snap = await Snapshot.create(web3.currentProvider);
        
        //Create distributions
        for(let i=0; i<50; i++){
            let randUser = Math.round(5*Math.random());
            await deposit(otherAccounts[randUser], w3random.interval(10, 20, 'ether'));

            await time.increase(7*24*60*60);
            await (<any>savings).distributeRewardsForced(compoundProtocolDai.address);
        }

        // Upgrade Savings
        savings = await upgradeProxy(savings.address, SavingsModule, UPGRADABLE_OPTS);
    });

    beforeEach(async () => {
        //await snap.revert();
    });


    it('should use low gas if migrate rewards for user not participated in a pool', async () => {
        let tx = await rewardDistributions.migrateRewards([user]);
        //console.log(tx);
        let gasUsed = tx.receipt.gasUsed;
        expect(gasUsed).to.be.lt(100000);
    });

    it('should use low gas if withdraw rewards for user not participated in a pool', async () => {
        let tx = await rewardDistributions.methods['withdrawReward()']({from:user});
        //console.log(tx);
        let gasUsed = tx.receipt.gasUsed;
        expect(gasUsed).to.be.lt(100000);
    });

    async function deposit(acc:string, amount:BN){
        await dai.methods['mint(address,uint256)'](acc, amount);
        await dai.approve(savings.address, amount, {from:acc});
console.log('deposit', acc, amount.toString());
        await savings.methods['deposit(address,address[],uint256[])'](compoundProtocolDai.address, [dai.address], [amount], {from:acc});
console.log('deposit-done');        
    }

});
