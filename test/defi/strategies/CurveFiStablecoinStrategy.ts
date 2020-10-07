import { 
    VaultPoolTokenContract, VaultPoolTokenInstance,
    VaultProtocolContract, VaultProtocolInstance,
    PoolContract, PoolInstance,
    AccessModuleContract, AccessModuleInstance,
    TestErc20Contract, TestErc20Instance,
    TestYerc20Contract, TestYerc20Instance,
    VaultSavingsModuleContract, VaultSavingsModuleInstance,
    CurveFiStablecoinStrategyContract, CurveFiStablecoinStrategyInstance,
    CurveFiDepositStubYContract, CurveFiDepositStubYInstance,
    CurveFiSwapStubYContract, CurveFiSwapStubYInstance,
    CurveFiTokenStubYContract, CurveFiTokenStubYInstance,
    CurveFiMinterStubContract, CurveFiMinterStubInstance,
    CurveFiLiquidityGaugeStubContract, CurveFiLiquidityGaugeStubInstance,
    UniswapStubContract, UniswapStubInstance
} from "../../../types/truffle-contracts/index";

// tslint:disable-next-line:no-var-requires
const { BN, constants, expectEvent, shouldFail, time } = require("@openzeppelin/test-helpers");
// tslint:disable-next-line:no-var-requires
import Snapshot from "../../utils/snapshot";
const { expect, should } = require('chai');

const expectRevert= require("../../utils/expectRevert");
const expectEqualBN = require("../../utils/expectEqualBN");
const w3random = require("../../utils/w3random");

const ERC20 = artifacts.require("TestERC20");
const YERC20 = artifacts.require("TestYERC20");

const CurveStrategy = artifacts.require("CurveFiStablecoinStrategy");
const VaultProtocol = artifacts.require("VaultProtocol");
const VaultSavings = artifacts.require("VaultSavingsModule");
const VaultPoolToken = artifacts.require("VaultPoolToken");
const Pool = artifacts.require("Pool");
const AccessModule = artifacts.require("AccessModule");

const CurveDeposit = artifacts.require("CurveFiDepositStub_Y");
const CurveSwap = artifacts.require("CurveFiSwapStub_Y");
const CurveToken = artifacts.require("CurveFiTokenStub_Y");
const CurveMinter = artifacts.require("CurveFiMinterStub");
const CurveGauge = artifacts.require("CurveFiLiquidityGaugeStub");
const Uniswap = artifacts.require("UniswapStub");

contract("CurveFiStablecoinStrategy", async ([_, owner, user1, user2, user3, defiops, protocolStub, ...otherAccounts]) => {
    let globalSnap: Snapshot;
    let vaultCurveStrategy: CurveFiStablecoinStrategyInstance;
    let vaultSavings: VaultSavingsModuleInstance;
    let vaultProtocol: VaultProtocolInstance;
    let vaultPoolToken: VaultPoolTokenInstance
    let dai: TestErc20Instance;
    let usdc: TestErc20Instance;
    let busd: TestErc20Instance;
    let tusd: TestErc20Instance;
    let weth: TestErc20Instance;
    let crvToken: TestErc20Instance;
    let pool: PoolInstance;
    let accessModule: AccessModuleInstance;

    let ydai: TestYerc20Instance;
    let yusdc: TestYerc20Instance;
    let ybusd: TestYerc20Instance;
    let ytusd: TestYerc20Instance;

    let curveDeposit: CurveFiDepositStubYInstance;
    let curveSwap: CurveFiSwapStubYInstance;
    let curveMinter: CurveFiMinterStubInstance;
    let curveGauge: CurveFiLiquidityGaugeStubInstance;
    let curveToken: CurveFiTokenStubYInstance;
    let uniswap: UniswapStubInstance;


    before(async () => {
        //Deposit token 1
        dai = await ERC20.new({from:owner});
        await (<any> dai).methods['initialize(string,string,uint8)']("DAI", "DAI", 18, {from:owner});
        //Deposit token 2
        usdc = await ERC20.new({from:owner});
        await (<any> usdc).methods['initialize(string,string,uint8)']("USDC", "USDC", 18, {from:owner});
        //Deposit token 3
        busd = await ERC20.new({from:owner});
        await (<any> busd).methods['initialize(string,string,uint8)']("BUSD", "BUSD", 18, {from:owner});
        //Deposit token 4
        tusd = await ERC20.new({from:owner});
        await (<any> tusd).methods['initialize(string,string,uint8)']("TUSD", "TUSD", 18, {from:owner});

    //Setup Curve and Uniswap
        ydai = await YERC20.new({from:owner});
        await (<any> ydai).methods['initialize(string,string,uint8,address)']("yDAI", "yDAI", 18, dai.address, {from:owner});
        yusdc = await YERC20.new({from:owner});
        await (<any> yusdc).methods['initialize(string,string,uint8,address)']("yUSDC", "yUSDC", 18, usdc.address, {from:owner});
        ybusd = await YERC20.new({from:owner});
        await (<any> ybusd).methods['initialize(string,string,uint8,address)']("yBUSD", "yBUSD", 18, busd.address, {from:owner});
        ytusd = await YERC20.new({from:owner});
        await (<any> ytusd).methods['initialize(string,string,uint8,address)']("yTUSD", "yTUSD", 18, tusd.address, {from:owner});

        curveSwap = await CurveSwap.new({from: owner});
        await (<any> curveSwap).methods['initialize(address[4])'](
            [ydai.address, yusdc.address, ybusd.address, ytusd.address], 
            {from: owner});
        
        curveDeposit = await CurveDeposit.new({from:owner});
        await (<any> curveDeposit).methods['initialize(address)'](curveSwap.address, {from:owner});

        crvToken = await ERC20.new({from:owner});
        await (<any> crvToken).methods['initialize(string,string,uint8)']("CRV", "CRV", 18, {from:owner});

        curveMinter = await CurveMinter.new({from:owner});
        await curveMinter.initialize(crvToken.address, {from:owner});
        await crvToken.addMinter(curveMinter.address, {from:owner});

        let curveToken = await curveDeposit.token({from:owner});

        curveGauge = await CurveGauge.new({from:owner});
        await curveGauge.initialize(curveToken, curveMinter.address, crvToken.address);

        weth = await ERC20.new({from:owner});
        await (<any> weth).methods['initialize(string,string,uint8)']("WETH", "WETH", 18, {from:owner});

        uniswap = await Uniswap.new({from:owner});
    //Setup pool
        pool = await Pool.new({from:owner});
        await (<any> pool).methods['initialize()']({from: owner});

        accessModule = await AccessModule.new({from: owner});
        await accessModule.methods['initialize(address)'](pool.address, {from: owner});

        await pool.set("access", accessModule.address, true, {from:owner});

        vaultSavings = await VaultSavings.new({from: owner});
        await (<any> vaultSavings).methods['initialize(address)'](pool.address, {from: owner});
        await vaultSavings.addDefiOperator(defiops, {from:owner});

        await pool.set("vault", vaultSavings.address, true, {from:owner});
    //Setup Vault
        vaultProtocol = await VaultProtocol.new({from:owner});

        await (<any> vaultProtocol).methods['initialize(address,address[])'](pool.address, [dai.address, usdc.address, busd.address, tusd.address], {from: owner});

        await vaultProtocol.addDefiOperator(vaultSavings.address, {from:owner});
        await vaultProtocol.addDefiOperator(defiops, {from:owner});

    //Setup strategy
        vaultCurveStrategy = await CurveStrategy.new({from:owner});
        await (<any> vaultCurveStrategy).methods['initialize(address)'](pool.address, {from: owner});

        await vaultCurveStrategy.setProtocol(
            curveDeposit.address, curveGauge.address, curveMinter.address, uniswap.address, weth.address, 0, 
            {from:owner});

        await vaultCurveStrategy.addDefiOperator(vaultProtocol.address, {from:owner});
        await vaultCurveStrategy.addDefiOperator(defiops, {from:owner});

        //Register vault strategy
        await vaultProtocol.registerStrategy(vaultCurveStrategy.address, {from:owner});

    //Setup LP token
        vaultPoolToken = await VaultPoolToken.new({from: owner});

        await (<any> vaultPoolToken).methods['initialize(address,string,string)'](pool.address, "VaultSavings", "VLT", {from: owner});

        await vaultPoolToken.addMinter(vaultSavings.address, {from:owner});
        await vaultPoolToken.addMinter(vaultProtocol.address, {from:owner});
        await vaultPoolToken.addMinter(defiops, {from:owner});

        //Add liquidity to have some LP tokens minted
        await dai.approve(curveDeposit.address, 1000, {from:owner});
        await usdc.approve(curveDeposit.address, 1000, {from:owner});
        await busd.approve(curveDeposit.address, 1000, {from:owner});
        await tusd.approve(curveDeposit.address, 1000, {from:owner});

    //add into the deposit
        await curveDeposit.add_liquidity([100,100,100,100], 0, {from:owner});

        await vaultSavings.registerVault(vaultProtocol.address, vaultPoolToken.address, {from: owner});
        //Preliminary balances
        await dai.transfer(user1, 1000, {from:owner});
        await dai.transfer(user2, 1000, {from:owner});
        await dai.transfer(user3, 1000, {from:owner});

        await usdc.transfer(user1, 1000, {from:owner});
        await usdc.transfer(user2, 1000, {from:owner});
        await usdc.transfer(user3, 1000, {from:owner});

        await busd.transfer(user1, 1000, {from:owner});
        await busd.transfer(user2, 1000, {from:owner});
        await busd.transfer(user3, 1000, {from:owner});

        await tusd.transfer(user1, 1000, {from:owner});
        await tusd.transfer(user2, 1000, {from:owner});
        await tusd.transfer(user3, 1000, {from:owner});

        globalSnap = await Snapshot.create(web3.currentProvider);

    });


    describe('Deposit into the strategy', () => {
        afterEach(async () => {
            await globalSnap.revert();
        });
    });

    describe('Withdraw from the strategy', () => {
        afterEach(async () => {
            await globalSnap.revert();
        });
    });

    describe('Perform strategy', () => {
        afterEach(async () => {
            await globalSnap.revert();
        });
    });

    describe('Full cycle', () => {
        beforeEach(async () =>{
            await dai.approve(vaultProtocol.address, 100, {from:user1});
            await usdc.approve(vaultProtocol.address, 100, {from:user1});
            await busd.approve(vaultProtocol.address, 100, {from:user1});
            await tusd.approve(vaultProtocol.address, 100, {from:user1});

        });

        afterEach(async () => {
            await globalSnap.revert();
        });

        it('Full cycle', async () => {
            await (<any> vaultSavings).methods['deposit(address,address[],uint256[])'](vaultProtocol.address,
                [dai.address, usdc.address, busd.address, tusd.address], [10, 20, 30, 40],
                {from:user1});

            await vaultSavings.handleWithdrawRequests(vaultProtocol.address, {from:defiops});

        });
    });
});