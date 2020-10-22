import { 
    FreeErc20Contract,FreeErc20Instance,
    VestedAkroContract,VestedAkroInstance
} from "../types/truffle-contracts/index";

const { BN, constants, expectEvent, shouldFail, time } = require("@openzeppelin/test-helpers");
const { promisify } = require('util');
import Snapshot from "./utils/snapshot";
const should = require("chai").should();
const expect = require("chai").expect;
const expectRevert= require("./utils/expectRevert");
const expectEqualBN = require("./utils/expectEqualBN");
const w3random = require("./utils/w3random");

const FreeERC20 = artifacts.require("FreeERC20");
const VestedAkro = artifacts.require("VestedAkro");

contract("VestedAkro", async ([owner, sender, user, ...otherAccounts]) => {
    const vestingPeriod = 365*24*60*60;
    let snap: Snapshot;
    let akro: FreeErc20Instance;
    let vAkro: VestedAkroInstance;

    before(async () => {
        akro = await FreeERC20.new();
        await (<any> akro).methods['initialize(string,string)']("Akropolis","AKRO",{from: owner});

        vAkro = await VestedAkro.new();
        await (<any> vAkro).methods['initialize(address,uint256)'](akro.address, vestingPeriod, {from: owner});

        //Setup roles
        await vAkro.addSender(sender);

        //Prepare liquidity
        await akro.methods['mint(address,uint256)'](owner, web3.utils.toWei('1000000000'));

        //Save snapshot
        //snap = await Snapshot.create(web3.currentProvider);
    });

    it('should mint vAKRO to Sender locking AKRO', async () => {
        const before = {
            ownerAkro: await akro.balanceOf(owner),
            senderAkro: await akro.balanceOf(sender),
            senderVAkro: await vAkro.balanceOf(sender),
            senderVAkroBI: await vAkroBalanceInfo(sender),
            vAkroTS: await vAkro.totalSupply()
        }

        let amount = w3random.interval(1000000, 2000000, 'ether');
        expect(amount).to.be.bignumber.lt(before.ownerAkro);

        await akro.approve(vAkro.address, amount);
        await vAkro.mint(sender, amount);

        const after = {
            ownerAkro: await akro.balanceOf(owner),
            senderAkro: await akro.balanceOf(sender),
            senderVAkro: await vAkro.balanceOf(sender),
            senderVAkroBI: await vAkroBalanceInfo(sender),
            vAkroTS: await vAkro.totalSupply()
        }
        expect(after.ownerAkro).to.be.bignumber.eq(before.ownerAkro.sub(amount));
        expect(after.senderAkro).to.be.bignumber.eq(before.senderAkro);
        expect(after.senderVAkro).to.be.bignumber.eq(before.senderVAkro.add(amount));
        expect(after.senderVAkroBI.locked).to.be.bignumber.eq(before.senderVAkroBI.locked);
        expect(after.senderVAkroBI.unlocked).to.be.bignumber.eq(before.senderVAkroBI.unlocked.add(amount));
        expect(after.senderVAkroBI.unlockable).to.be.bignumber.eq(before.senderVAkroBI.unlockable);
        expect(after.vAkroTS).to.be.bignumber.eq(before.vAkroTS.add(amount));
    });

    it('should deny Sender to redeem AKRO', async () => {
        await expectRevert(
            vAkro.unlockAndRedeemAll({from:sender}),
            "VestedAkro: VestedAkroSender is not allowed to redeem"
        );
    });

    it('should allow Sender to transfer vAKRO to user and lock it', async () => {
        const before = {
            senderVAkroBI: await vAkroBalanceInfo(sender),
            userVAkroBI: await vAkroBalanceInfo(user),
        }
        //user should not have his own vAKRO fro this test
        expect(before.userVAkroBI.locked).to.be.bignumber.eq(new BN('0'));
        expect(before.userVAkroBI.unlocked).to.be.bignumber.eq(new BN('0'));
        expect(before.userVAkroBI.unlockable).to.be.bignumber.eq(new BN('0'));

        let amount = w3random.interval(100, 200, 'ether');
        expect(amount).to.be.bignumber.lt(before.senderVAkroBI.unlocked);

        await vAkro.transfer(user, amount, {from:sender});

        const after = {
            senderVAkroBI: await vAkroBalanceInfo(sender),
            userVAkroBI: await vAkroBalanceInfo(user),
        }
        expect(after.senderVAkroBI.unlocked).to.be.bignumber.eq(before.senderVAkroBI.unlocked.sub(amount));
        expect(after.userVAkroBI.locked).to.be.bignumber.eq(amount);
        expectEqualBN(after.userVAkroBI.unlockable, new BN('0'), 18, -6); //Some time may pass betwin transfer and read, so something might be unlocked
    });

    it('should allow user to redeem partially unlocked AKRO', async () => {
        const periodPartPassed = 2;    //Half period passed:  1/n-th

        // console.log('vp', (await vAkro.vestingPeriod()).toString());
        // console.log('now1', (await time.latest()).toString());

        // let batchInfo = await vAkro.batchInfo(user, 0);
        // console.log('batchInfo', batchInfo[1].toString(), batchInfo[2].toString());


        // const beforeTS = {
        //     userAkro: await akro.balanceOf(user),
        //     userVAkroBI: await vAkroBalanceInfo(user),
        // }
        // console.log('beforeTS.userAkro', beforeTS.userAkro.toString());
        // console.log('beforeTS.userVAkroBI.locked', beforeTS.userVAkroBI.locked.toString());
        // console.log('beforeTS.userVAkroBI.unlocked', beforeTS.userVAkroBI.unlocked.toString());
        // console.log('beforeTS.userVAkroBI.unlockable', beforeTS.userVAkroBI.unlockable.toString());

        // console.log('now1a', (await time.latest()).toString());

        await increaseTime(vestingPeriod/periodPartPassed);

        // console.log('now2', (await time.latest()).toString());

        const before = {
            userAkro: await akro.balanceOf(user),
            userVAkroBI: await vAkroBalanceInfo(user),
        }
        // console.log('before.userAkro', before.userAkro.toString());
        // console.log('before.userVAkroBI.locked', before.userVAkroBI.locked.toString());
        // console.log('before.userVAkroBI.unlocked', before.userVAkroBI.unlocked.toString());
        // console.log('before.userVAkroBI.unlockable', before.userVAkroBI.unlockable.toString());
        expect(before.userAkro).to.be.bignumber.eq(new BN('0')); // user should not have his own AKRO for this test

        // Check correct unlockable amount
        expectEqualBN(before.userVAkroBI.unlockable, before.userVAkroBI.locked.divn(periodPartPassed), 18, -17);

        await vAkro.unlockAndRedeemAll({from:user});

        const after = {
            userAkro: await akro.balanceOf(user),
            userVAkroBI: await vAkroBalanceInfo(user),
        }

        // console.log('after', after.userVAkroBI);
        // console.log('after.userAkro', after.userAkro);
        expectEqualBN(after.userAkro, before.userVAkroBI.unlockable, 18, -4); //diff is so high because time passes between transactions
    });

    it('should allow user to fully redeem AKRO after vesting period end', async () => {
        await time.increase(vestingPeriod);

        const before = {
            userAkro: await akro.balanceOf(user),
            userVAkroBI: await vAkroBalanceInfo(user),
        }

        expectEqualBN(before.userVAkroBI.unlockable, before.userVAkroBI.locked); //Everything is unlockable

        await vAkro.unlockAndRedeemAll({from:user});

        const after = {
            userAkro: await akro.balanceOf(user),
            userVAkroBI: await vAkroBalanceInfo(user),
        }

        expectEqualBN(after.userAkro, before.userAkro.add(before.userVAkroBI.unlockable));

        //No vAkro should be left
        expect(after.userVAkroBI.locked).to.be.bignumber.eq(new BN('0'));
        expect(after.userVAkroBI.unlocked).to.be.bignumber.eq(new BN('0'));
        expect(after.userVAkroBI.unlockable).to.be.bignumber.eq(new BN('0'));

    });


    async function vAkroBalanceInfo(sender:string) {
        let bi = await vAkro.balanceInfoOf(sender);
        return {
            locked: bi[0],
            unlocked: bi[1],
            unlockable: bi[2]
        };
    }

    async function increaseTime(duration: number) {
        //const now = Number((await time.latest()).toString());
        const now = await time.latest();
        //console.log('now', now.toString());
        return promisify(web3.currentProvider.send.bind(web3.currentProvider))({
            jsonrpc: '2.0',
            method: 'evm_mine',
            params: [now.addn(duration).toString()],
            id: new Date().getTime(),
        });
    }

});