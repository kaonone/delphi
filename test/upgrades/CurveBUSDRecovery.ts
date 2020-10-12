import { 
    PoolContract, PoolInstance, 
    AccessModuleContract, AccessModuleInstance,
    SavingsModuleContract, SavingsModuleInstance,
    SavingsModuleOldContract,SavingsModuleOldInstance,
    RewardDistributionModuleContract,RewardDistributionModuleInstance,
    RewardVestingModuleContract, RewardVestingModuleInstance,
    PoolTokenContract,PoolTokenInstance,
    PoolTokenOldContract,PoolTokenOldInstance,
    StakingPoolContract,StakingPoolInstance,
    StakingPoolAdelContract,StakingPoolAdelInstance,
    FreeErc20Contract,FreeErc20Instance,
    YTokenStubContract, YTokenStubInstance   
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
const YTokenStub = artifacts.require("YTokenStub");

const Pool = artifacts.require("Pool");
const AccessModule = artifacts.require("AccessModule");
const SavingsModule = artifacts.require("SavingsModule");
const SavingsModuleOld = artifacts.require("SavingsModuleOld");
const RewardVestingModule = artifacts.require("RewardVestingModule");
const RewardDistributionModule = artifacts.require("RewardDistributionModule");
const CompoundProtocol = artifacts.require("CompoundProtocol");
const PoolToken = artifacts.require("PoolToken");
const PoolTokenOld = artifacts.require("PoolTokenOld");

const StakingPool  =  artifacts.require("StakingPool");
const StakingPoolADEL  =  artifacts.require("StakingPoolADEL");

contract("Upgrades: migrate rewards from Savings to RewardDistribution", async ([owner, user, ...otherAccounts]) => {
    //let snap:Snapshot;

    let dai:FreeErc20Instance;
    let usdc:FreeErc20Instance;
    let usdt:FreeErc20Instance;
    let busd:FreeErc20Instance;
    let yDai:YTokenStubInstance;
    let yUsdc:YTokenStubInstance;
    let yUsdt:YTokenStubInstance;
    let yBusd:YTokenStubInstance;
 

    let pool:PoolInstance;
    let access:AccessModuleInstance;
    let savings:SavingsModuleOldInstance|SavingsModuleInstance;
    let rewardDistributions:RewardDistributionModuleInstance;
    let rewardVesting:RewardVestingModuleInstance;
    let poolTokenCompoundProtocolDai:PoolTokenOldInstance|PoolTokenInstance;    
    let akro:FreeErc20Instance;
    let adel:FreeErc20Instance;
    let stakingPoolAkro:StakingPoolInstance;
    let stakingPoolAdel:StakingPoolAdelInstance;


    before(async () => {
        //Setup external contracts
        dai = await deployProxy(FreeERC20, ["Dai Stablecoin", "DAI"], UPGRADABLE_OPTS);
        usdc = await deployProxy(FreeERC20, ["USD Coin", "USDC", 6], UPGRADABLE_OPTS);
        usdt = await deployProxy(FreeERC20, ["USD Tether", "USDT", 6], UPGRADABLE_OPTS);
        busd = await deployProxy(FreeERC20, ["Binance USD", "BUSD", 18], UPGRADABLE_OPTS);

        yDai = await deployProxy(FreeERC20, [dai.address, "yDAI", 18], UPGRADABLE_OPTS);
        yUsdc = await deployProxy(FreeERC20, [usdc.address, "yUSDC", 18], UPGRADABLE_OPTS);
        yUsdt = await deployProxy(FreeERC20, [usdt.address, "yUSDT", 18], UPGRADABLE_OPTS);
        yBusd = await deployProxy(FreeERC20, [busd.address, "yBUSD", 18], UPGRADABLE_OPTS);

        //Setup system contracts
        pool = await deployProxy(Pool, [], UPGRADABLE_OPTS);

        access = await deployProxy(AccessModule, [pool.address], UPGRADABLE_OPTS);
        await pool.set('access', access.address, false);

        savings = await deployProxy(SavingsModuleOld, [pool.address], UPGRADABLE_OPTS);
        await pool.set('savings', savings.address, false);

        akro = await deployProxy(FreeERC20, ["Akropolis", "AKRO"], UPGRADABLE_OPTS);
        await pool.set('akro', akro.address, false);
        adel = await deployProxy(FreeERC20, ["Akropolis Delphi", "ADEL"], UPGRADABLE_OPTS);
        await pool.set('adel', adel.address, false);

        stakingPoolAkro = await deployProxy(StakingPool, [pool.address, akro.address, '0'], UPGRADABLE_OPTS);
        await pool.set('staking', stakingPoolAkro.address, false);
        stakingPoolAdel = await deployProxy(StakingPoolADEL, [pool.address, adel.address, '0'], UPGRADABLE_OPTS);
        await pool.set('stakingAdel', stakingPoolAdel.address, false);

        // compoundProtocolDai = await deployProxy(CompoundProtocol, [pool.address, dai.address, cDai.address, comptroller.address], UPGRADABLE_OPTS);
        // poolTokenCompoundProtocolDai = await deployProxy(PoolTokenOld, [pool.address, "Delphi Compound DAI","dCDAI"], UPGRADABLE_OPTS);
        // await savings.registerProtocol(compoundProtocolDai.address, poolTokenCompoundProtocolDai.address);
        // await compoundProtocolDai.addDefiOperator(savings.address);
        // await poolTokenCompoundProtocolDai.addMinter(savings.address);

        rewardVesting = await deployProxy(RewardVestingModule, [pool.address], UPGRADABLE_OPTS);
        await pool.set('reward', rewardVesting.address, false);

        // rewardDistributions = await deployProxy(RewardDistributionModule, [pool.address], UPGRADABLE_OPTS);
        // await pool.set('rewardDistributions', rewardDistributions.address, false);
        // await rewardDistributions.registerProtocol(compoundProtocolDai.address, poolTokenCompoundProtocolDai.address);
        // await compoundProtocolDai.addDefiOperator(rewardDistributions.address);

        //Save snapshot
        //snap = await Snapshot.create(web3.currentProvider);
    });

    beforeEach(async () => {
        //await snap.revert();
    });




});
