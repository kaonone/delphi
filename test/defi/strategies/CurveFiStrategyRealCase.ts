import {
    VaultPoolTokenContract, VaultPoolTokenInstance,
    VaultProtocolContract, VaultProtocolInstance,
    PoolContract, PoolInstance,
    AccessModuleContract, AccessModuleInstance,
    TestErc20Contract, TestErc20Instance,
    YTokenStubContract, YTokenStubInstance,
    VaultSavingsModuleContract, VaultSavingsModuleInstance,
    CurveFiStablecoinStrategyContract, CurveFiStablecoinStrategyInstance,
    CurveFiDepositStubYContract, CurveFiDepositStubYInstance,
    CurveFiSwapStubYContract, CurveFiSwapStubYInstance,
    CurveFiTokenStubYContract, CurveFiTokenStubYInstance,
    CurveFiMinterStubContract, CurveFiMinterStubInstance,
    CurveFiLiquidityGaugeStubContract, CurveFiLiquidityGaugeStubInstance,
    DexagStubContract, DexagStubInstance
} from '../../../types/truffle-contracts/index';

const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';

// tslint:disable-next-line:no-var-requires
const { BN, constants, expectEvent, shouldFail, time } = require('@openzeppelin/test-helpers');
// tslint:disable-next-line:no-var-requires
import Snapshot from '../../utils/snapshot';
const { expect, should } = require('chai');

const expectRevert = require('../../utils/expectRevert');
const expectEqualBN = require('../../utils/expectEqualBN');
const w3random = require('../../utils/w3random');

const ERC20 = artifacts.require('TestERC20');
const YERC20 = artifacts.require('YTokenStub');

const CurveStrategy = artifacts.require('CurveFiStablecoinStrategy');
const VaultProtocol = artifacts.require('VaultProtocol');
const VaultSavings = artifacts.require('VaultSavingsModule');
const VaultPoolToken = artifacts.require('VaultPoolToken');
const Pool = artifacts.require('Pool');
const AccessModule = artifacts.require('AccessModule');

const CurveDeposit = artifacts.require('CurveFiDepositStub_Y');
const CurveSwap = artifacts.require('CurveFiSwapStub_Y');
const CurveToken = artifacts.require('CurveFiTokenStub_Y');
const CurveMinter = artifacts.require('CurveFiMinterStub');
const CurveGauge = artifacts.require('CurveFiLiquidityGaugeStub');
const Dexag = artifacts.require('DexagStub');

contract('CurveFi strategy: real case', async([ owner, user1, user2, user3, defiops, protocolStub ]) => {

    let globalSnap: Snapshot;
    let vaultCurveStrategy: CurveFiStablecoinStrategyInstance;
    let vaultSavings: VaultSavingsModuleInstance;
    let vault: VaultProtocolInstance;
    let poolToken: VaultPoolTokenInstance;
    let dai: TestErc20Instance;
    let usdc: TestErc20Instance;
    let busd: TestErc20Instance;
    let usdt: TestErc20Instance;
    let weth: TestErc20Instance;
    let crvToken: TestErc20Instance;
    let pool: PoolInstance;
    let accessModule: AccessModuleInstance;
    let tokens: string[];

    let ydai: YTokenStubInstance;
    let yusdc: YTokenStubInstance;
    let ybusd: YTokenStubInstance;
    let yusdt: YTokenStubInstance;

    let curveDeposit: CurveFiDepositStubYInstance;
    let curveSwap: CurveFiSwapStubYInstance;
    let curveMinter: CurveFiMinterStubInstance;
    let curveGauge: CurveFiLiquidityGaugeStubInstance;
    let curveToken: CurveFiTokenStubYInstance;
    let dexag: DexagStubInstance;

    before(async() => {
        // Deposit token 1
        dai = await ERC20.new({ from: owner });
        await (<any> dai).methods['initialize(string,string,uint8)']('DAI', 'DAI', 18, { from: owner });
        await dai.mint(owner, new BN('50000000000000000000000'), {from:owner});
        // Deposit token 2
        usdc = await ERC20.new({ from: owner });
        await (<any> usdc).methods['initialize(string,string,uint8)']('USDC', 'USDC', 6, { from: owner });
        await usdc.mint(owner, 500000000000, {from:owner});
        // Deposit token 3
        busd = await ERC20.new({ from: owner });
        await (<any> busd).methods['initialize(string,string,uint8)']('BUSD', 'BUSD', 6, { from: owner });
        await busd.mint(owner, 500000000000, {from:owner});
        // Deposit token 4
        usdt = await ERC20.new({ from: owner });
        await (<any> usdt).methods['initialize(string,string,uint8)']('usdt', 'usdt', 18, { from: owner });
        await usdt.mint(owner, new BN('50000000000000000000000'), {from:owner});

        tokens = [dai.address, usdc.address, busd.address, usdt.address];

        // Setup Curve and Uniswap
        ydai = await YERC20.new({ from: owner });
        await (<any> ydai).methods['initialize(address,string,uint8)'](dai.address, 'yDAI', 18,
            { from: owner });
        yusdc = await YERC20.new({ from: owner });
        await (<any> yusdc).methods['initialize(address,string,uint8)'](usdc.address, 'yUSDC', 6,
            { from: owner });
        ybusd = await YERC20.new({ from: owner });
        await (<any> ybusd).methods['initialize(address,string,uint8)'](busd.address, 'yBUSD', 6,
            { from: owner });
        yusdt = await YERC20.new({ from: owner });
        await (<any> yusdt).methods['initialize(address,string,uint8)'](usdt.address, 'yusdt', 18,
            { from: owner });

        curveSwap = await CurveSwap.new({ from: owner });
        await (<any> curveSwap).methods['initialize(address[4])'](
            [ydai.address, yusdc.address, ybusd.address, yusdt.address],
            { from: owner });

        curveDeposit = await CurveDeposit.new({ from: owner });
        await (<any> curveDeposit).methods['initialize(address)'](curveSwap.address, { from: owner });

        crvToken = await ERC20.new({ from: owner });
        await (<any> crvToken).methods['initialize(string,string,uint8)']('CRV', 'CRV', 18, { from: owner });

        curveMinter = await CurveMinter.new({ from: owner });
        await curveMinter.initialize(crvToken.address, { from: owner });
        await crvToken.addMinter(curveMinter.address, { from: owner });

        const curveToken = await curveDeposit.token({ from: owner });

        curveGauge = await CurveGauge.new({ from: owner });
        await curveGauge.initialize(curveToken, curveMinter.address, crvToken.address);

        weth = await ERC20.new({ from: owner });
        await (<any> weth).methods['initialize(string,string,uint8)']('WETH', 'WETH', 18, { from: owner });

        dexag = await Dexag.new({ from: owner });
        await dexag.setProtocol(weth.address, { from: owner });
        //Setup pool
        pool = await Pool.new({ from: owner });
        await (<any> pool).methods['initialize()']({ from: owner });

        accessModule = await AccessModule.new({ from: owner });
        await accessModule.methods['initialize(address)'](pool.address, { from: owner });

        await pool.set('access', accessModule.address, true, { from: owner });

        vaultSavings = await VaultSavings.new({ from: owner });
        await (<any> vaultSavings).methods['initialize(address)'](pool.address, { from: owner });
        await vaultSavings.addVaultOperator(defiops, { from: owner });

        await pool.set('vault', vaultSavings.address, true, { from: owner });
        //Setup Vault
        vault = await VaultProtocol.new({ from: owner });

        await (<any> vault).methods['initialize(address,address[])'](pool.address,
            [dai.address, usdc.address, busd.address, usdt.address], { from: owner });

        await vault.addDefiOperator(vaultSavings.address, { from: owner });
        await vault.addDefiOperator(defiops, { from: owner });

        await vault.setAvailableEnabled(true, { from: owner });

        //Setup strategy
        vaultCurveStrategy = await CurveStrategy.new({ from: owner });
        await (<any> vaultCurveStrategy).methods['initialize(address,string)'](pool.address, 'CRV-UNI-DAI',
            { from: owner });

        await vaultCurveStrategy.setProtocol(
            curveDeposit.address, curveGauge.address, curveMinter.address, dexag.address,
            { from: owner });

        await vaultCurveStrategy.addDefiOperator(vault.address, { from: owner });
        await vaultCurveStrategy.addDefiOperator(defiops, { from: owner });

        //Register vault strategy
        await vault.registerStrategy(vaultCurveStrategy.address, { from: owner });
        await vault.setQuickWithdrawStrategy(vaultCurveStrategy.address, { from: defiops });

        //Setup LP token
        poolToken = await VaultPoolToken.new({ from: owner });

        await (<any> poolToken).methods['initialize(address,string,string)'](
            pool.address, 'VaultSavings', 'VLT', { from: owner });

        await poolToken.addMinter(vaultSavings.address, { from: owner });
        await poolToken.addMinter(vault.address, { from: owner });
        await poolToken.addMinter(defiops, { from: owner });

        //Add liquidity to have some LP tokens minted
        await dai.approve(curveDeposit.address, new BN('2000000000000000000000'), { from: owner });
        await usdc.approve(curveDeposit.address, 2000000000, { from: owner });
        await busd.approve(curveDeposit.address, 2000000000, { from: owner });
        await usdt.approve(curveDeposit.address, new BN('2000000000000000000000'), { from: owner });

        //add into the deposit
        await curveDeposit.add_liquidity([new BN('2000000000000000000000'), 2000000000, 2000000000, new BN('2000000000000000000000')], 0, { from: owner });

        await vaultSavings.registerVault(vault.address, poolToken.address, { from: owner });
        //Preliminary balances
        await dai.transfer(user1, new BN('1000000000000000000000'), { from: owner });
        await dai.transfer(user2, 1000, { from: owner });
        await dai.transfer(user3, 1000, { from: owner });

        await usdc.transfer(user1, 1000000000, { from: owner });
        await usdc.transfer(user2, 1000, { from: owner });
        await usdc.transfer(user3, 1000, { from: owner });

        await busd.transfer(user1, 1000000000, { from: owner });
        await busd.transfer(user2, 1000, { from: owner });
        await busd.transfer(user3, 1000, { from: owner });

        await usdt.transfer(user1, new BN('1000000000000000000000'), { from: owner });
        await usdt.transfer(user2, 1000, { from: owner });
        await usdt.transfer(user3, 1000, { from: owner });

        globalSnap = await Snapshot.create(web3.currentProvider);
    });

    afterEach(async() => await globalSnap.revert());

    describe('Deposit + withdraw', () => {
        it('Full case', async() => {
        //Preliminary
            await vault.setAvailableEnabled(false, {from:owner});
            await vaultSavings.setVaultRemainder(vault.address, new BN('1000000000000000000'), 0, {from:defiops});
            await vaultSavings.setVaultRemainder(vault.address, 1000000, 1, {from:defiops});
            await vaultSavings.setVaultRemainder(vault.address, 1000000, 2, {from:defiops});
            await vaultSavings.setVaultRemainder(vault.address, new BN('1000000000000000000'), 3, {from:defiops});

            await dai.approve(vaultSavings.address, new BN('1000000000000000000'), { from: owner });
            await usdc.approve(vaultSavings.address, 1000000, { from: owner });
            await busd.approve(vaultSavings.address, 1000000, { from: owner });
            await usdt.approve(vaultSavings.address, new BN('1000000000000000000'), { from: owner });
            await (<VaultSavingsModuleInstance>vaultSavings).methods['deposit(address,address[],uint256[])'](
                vault.address, [dai.address, usdc.address, busd.address, usdt.address],
                [new BN('1000000000000000000'),1000000,1000000,new BN('1000000000000000000')], { from: owner });

        //Deposit
            await dai.approve(vaultSavings.address, new BN('50000000000000000000'), { from: user1 });
            await usdc.approve(vaultSavings.address, 50000000, { from: user1 });
            //await busd.approve(vaultSavings.address, 50000000, { from: user1 });
            //await usdt.approve(vaultSavings.address, new BN('50000000000000000000'), { from: user1 });

            await (<VaultSavingsModuleInstance>vaultSavings).methods['deposit(address,address[],uint256[])'](
                vault.address, [dai.address, usdc.address],
                [new BN('50000000000000000000'), 50000000], { from: user1 });

        //Withdraw
            await vaultSavings.withdraw(vault.address, [dai.address, busd.address], [new BN('15000000000000000000'), 10000000], { from: user1 });
            
        //Operation
            const beforeOp = {
                user1: await poolToken.balanceOf(user1)
            };
            await vaultSavings.handleOperatorActions(
                vault.address, vaultCurveStrategy.address, ZERO_ADDRESS, { from: defiops });
            const afterOp = {
                user1: await poolToken.balanceOf(user1)
            };

            expect(afterOp.user1.sub(beforeOp.user1).toString(), "No new pool tokens should be minted").to.equal("0");

            //Nevertheless, depending on the fee calculated within CurveFiSwap, there can be a bonus
            // so yield may be expected
            //console.log((await poolToken.calculateUnclaimedDistributions(user1)).toString());
            //console.log((await vaultCurveStrategy.normalizedBalance.call()).toString());


            //Verify, that amounts of LP tokens (vault and Curve) are compatible
            const vaultPoolAmount = await poolToken.balanceOf(user1);
            const curvePoolAmount = await vaultCurveStrategy.curveFiTokenBalance();

            //Get 2 decimals for precision
            const diff = curvePoolAmount.sub(vaultPoolAmount).div(new BN(10).pow(new BN(15))).toNumber() * 0.001;
            expect(diff, "Too much/few curve pool tokens minted").to.be.closeTo(0, 0.5)

            
            expect((await vault.claimableAmount(user1, dai.address)).toString(), "Incorrect claimable token (1)").to.equal('15000000000000000000');
            expect((await vault.claimableAmount(user1, busd.address)).toString(), "Incorrect claimable token (3)").to.equal('10000000');

            const beforeClaim = {
                dai: await dai.balanceOf(user1),
                busd: await busd.balanceOf(user1)
            };
            await vaultSavings.claimAllRequested(vault.address, {from: user1});
            const afterClaim = {
                dai: await dai.balanceOf(user1),
                busd: await busd.balanceOf(user1)
            };
            expect(afterClaim.dai.sub(beforeClaim.dai).toString(), "Token (1) not transferred").to.equal('15000000000000000000');
            expect(afterClaim.busd.sub(beforeClaim.busd).toString(), "Token (3) not transferred").to.equal('10000000');
            
        });
    });
});
