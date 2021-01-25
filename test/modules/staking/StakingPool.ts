import { 
    PoolContract, PoolInstance, 
    StakingPoolContract,StakingPoolInstance,
    StakingPoolADELContract,StakingPoolADELInstance,
    FreeERC20Contract,FreeERC20Instance,
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

const Pool = artifacts.require("Pool");
const StakingPool  =  artifacts.require("StakingPool");

contract("StakingPool", async ([owner, user, ...otherAccounts]) => {


    let pool:PoolInstance;
    let akro:FreeERC20Instance;
    let stakingPoolAkro:StakingPoolInstance;


    before(async () => {
        //Setup system contracts
        pool = await Pool.new();
        await pool.methods['initialize()']();

        akro = await FreeERC20.new();
        await akro.methods['initialize(string,string)']("Akropolis", "AKRO");
        await pool.set('akro', akro.address, false);

        stakingPoolAkro = await StakingPool.new();
        await stakingPoolAkro.methods['initialize(address,address,uint256)'](pool.address, akro.address, '0');
        await pool.set('staking', stakingPoolAkro.address, false);

        //Save snapshot
        //snap = await Snapshot.create(web3.currentProvider);
        
    });

    beforeEach(async () => {
        //await snap.revert();
    });


    it('should stake AKRO 50 times', async () => {
        for(let i=0; i<50; i++){
            let amount = w3random.interval(10, 20, 'ether');
            console.log(`Interation ${i}: staking ${web3.utils.fromWei(amount)} AKRO.`);
            await prepareTokenSpending(akro, user, stakingPoolAkro.address, amount);
            await stakingPoolAkro.stake(amount, "0x", {from:user});
            await time.increase(7*24*60*60);
        }
    });

    it('should withdraw all stakes with gas used < 100k', async () => {
        let tx = await stakingPoolAkro.unstakeAllUnlocked("0x", {from:user});
        //console.log(tx);
        let gasUsed = tx.receipt.gasUsed;
        expect(gasUsed).to.be.lt(100000);
    });



    async function prepareTokenSpending(token:FreeERC20Instance, sender:string, spender:string, amount: BN){
        await token.allocateTo(sender, amount, {from:sender});
        await token.approve(spender, amount, {from:sender});
    }

});
