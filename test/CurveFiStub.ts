const { BN, constants, expectEvent, shouldFail, time } = require("@openzeppelin/test-helpers");
import Snapshot from "./utils/snapshot";
const expect = require("chai").expect;
const expectRevert= require("./utils/expectRevert");
const expectEqualBN = require("./utils/expectEqualBN");
const w3random = require("./utils/w3random");

const ERC20Tools = artifacts.require("ERC20Tools");
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
        let erc20tools = await ERC20Tools.new();
        await erc20tools.allocateToNormalized(
            lp, 
            [dai.address, usdc.address, usdt.address, susd.address],
            web3.utils.toWei('1000000')
        ); 

    });

    beforeEach(async () => {
        //await snap.revert();
    });

    it('should allow deposit one token', async () => {
        let before = {
            lp_dai: dai.balanceOf(lp),
            lp_ct_susd: curveFiToken_SUSD.balanceOf(lp)
        };

        let deposit_amounts = [w3random.interval(1000, 2000, 'ether'), '0', '0', '0'];
        await curveFiDeposit_SUSD.add_liquidity(deposit_amounts, '0');

        let after = {
            lp_dai: dai.balanceOf(lp),
            lp_ct_susd: curveFiToken_SUSD.balanceOf(lp)
        };

        expect(after.lp_dai).to.be.bignumber.eq(before.lp_dai.sub(deposit_amounts[0]));

    });


});