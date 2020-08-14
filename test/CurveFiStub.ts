const { BN, constants, expectEvent, shouldFail, time } = require("@openzeppelin/test-helpers");
import Snapshot from "./utils/snapshot";
const expect = require("chai").expect;
const expectRevert= require("./utils/expectRevert");
const expectEqualBN = require("./utils/expectEqualBN");
const w3random = require("./utils/w3random");

const FreeERC20 = artifacts.require("FreeERC20");
const CurveFiSwapStub_SUSD = artifacts.require("CurveFiSwapStub_SUSD");
const CurveFiDepositStub_SUSD = artifacts.require("CurveFiDepositStub_SUSD");
const CurveFiTokenStub_SUSD = artifacts.require("CurveFiTokenStub_SUSD");


contract("CurveFiStub", async ([owner, lp, user, ...otherAccounts]) => {
    let snap: Snapshot;
    let dai, usdc, usdt, susd;    //tokens
    let curveFiDeposit_SUSD;
    let curveFiToken_SUSD;

    before(async () => {
        //Setup tokens
        dai = await FreeERC20.new();
        await dai.methods['initialize(string,string,uint8)']("Dai Stablecoin", "DAI", "18");
        usdc = await FreeERC20.new();
        await usdc.methods['initialize(string,string,uint8)']("USD Coin", "USDC", "6");
        usdt = await FreeERC20.new();
        await usdt.methods['initialize(string,string,uint8)']("Tether USD", "USDT", "6");
        susd = await FreeERC20.new();
        await susd.methods['initialize(string,string,uint8)']("Synth sUSD", "sUSD", "18");

        //Setup CurveFi
        let swap = await CurveFiSwapStub_SUSD.new();
        await swap.methods['initialize(address[4])']([dai.address, usdc.address, usdt.address, susd.address]);
        curveFiDeposit_SUSD = await CurveFiDepositStub_SUSD.new();
        await curveFiDeposit_SUSD.methods['initialize(address)'](swap.address);
        curveFiToken_SUSD = await FreeERC20.at(await swap.token());

        //Prepare liquidity provider
        await dai.allocateTo(lp, 

    });

    beforeEach(async () => {
        //await snap.revert();
    });

    // it('should not enable/disable whitelist from unauthorized user', async () => {
    //     await expectRevert(
    //         access.enableWhitelist({from:otherAccounts[0]}),
    //         'WhitelistAdminRole: caller does not have the WhitelistAdmin role'
    //     );
    //     await expectRevert(
    //         access.disableWhitelist({from:otherAccounts[0]}),
    //         'WhitelistAdminRole: caller does not have the WhitelistAdmin role'
    //     );
    // });
    // it('should enable/disable whitelist', async () => {
    //     let recept = await access.enableWhitelist({from:owner});
    //     expectEvent(recept, 'WhitelistEnabled');
    //     expect(await access.whitelistEnabled()).to.be.true;

    //     recept = await access.disableWhitelist({from:owner});
    //     expectEvent(recept, 'WhitelistDisabled');
    //     expect(await access.whitelistEnabled()).to.be.false;
    // });
    // it('should corectly handle not whitelisted user', async () => {
    //     await access.enableWhitelist({from:owner});

    //     let ops = Object.values(Operation).filter(o => (typeof o === "string"));
    //     for(let opName of ops){
    //         let op:number = (<any>Operation)[opName];
    //         let allowed = await access.isOperationAllowed(op, otherAccounts[0]);
    //         // if(alwaysAllowedOps.includes(op)){
    //         //     expect(allowed, `Operation ${opName} (${op}) should be allways allowed`).to.be.true;
    //         // }else{
    //         //     expect(allowed, `Operation ${opName} (${op}) should not be allowed`).to.be.false;
    //         // }
    //     }
    // });
    // it('should allow all to whitelisted user', async () => {
    //     await access.enableWhitelist({from:owner});
    //     await access.addWhitelisted(otherAccounts[1], {from:owner});

    //     let ops = Object.values(Operation).filter(o => (typeof o === "string"));
    //     for(let opName of ops){
    //         let op:number = (<any>Operation)[opName];
    //         let allowed = await access.isOperationAllowed(op, otherAccounts[1]);
    //         expect(allowed, `Operation ${opName} (${op}) should be allowed to whitelisted`).to.be.true;
    //     }
    // });

});