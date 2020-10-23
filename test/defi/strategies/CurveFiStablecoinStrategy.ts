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
    DexagStubContract, DexagStubInstance,
    YTokenStubContract, YTokenStubInstance,
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

contract('CurveFi stablecoin strategy', async([ owner, user1, user2, user3, defiops, protocolStub ]) => {

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


    const initial_liquidity = {
        dai: 100,
        usdc: 100,
        busd: 100,
        usdt: 100
    }

    function normalize(amount: number, decimals: number) {
        if (decimals < 18) {
            return amount * 10 ** (18 - decimals);
        } else if (decimals > 18) {
            return amount / 10 ** (decimals - 18);
        } else {
            return amount;
        }
    }
    before(async() => {
        // Deposit token 1
        dai = await ERC20.new({ from: owner });
        await (<any> dai).methods['initialize(string,string,uint8)']('DAI', 'DAI', 18, { from: owner });
        // Deposit token 2
        usdc = await ERC20.new({ from: owner });
        await (<any> usdc).methods['initialize(string,string,uint8)']('USDC', 'USDC', 6, { from: owner });
        // Deposit token 3
        busd = await ERC20.new({ from: owner });
        await (<any> busd).methods['initialize(string,string,uint8)']('BUSD', 'BUSD', 6, { from: owner });
        // Deposit token 4
        usdt = await ERC20.new({ from: owner });
        await (<any> usdt).methods['initialize(string,string,uint8)']('usdt', 'usdt', 18, { from: owner });

        tokens = [dai.address, usdc.address, busd.address, usdt.address];

        ydai = await YERC20.new({ from: owner });
        await (<any>ydai).methods['initialize(address,string,uint8)'](dai.address, 'yDAI', 18,
            { from: owner });
        yusdc = await YERC20.new({ from: owner });
        await (<any>yusdc).methods['initialize(address,string,uint8)'](usdc.address, 'yUSDC', 6,
            { from: owner });
        ybusd = await YERC20.new({ from: owner });
        await (<any>ybusd).methods['initialize(address,string,uint8)'](busd.address, 'yBUSD', 6,
            { from: owner });
        yusdt = await YERC20.new({ from: owner });
        await (<any>yusdt).methods['initialize(address,string,uint8)'](usdt.address, 'yusdt', 18,
            { from: owner });

        curveSwap = await CurveSwap.new({ from: owner });
        await (<any> curveSwap).methods['initialize(address[4])'](
            [ydai.address, yusdc.address, ybusd.address, yusdt.address], { from: owner });

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

        await (<any> vault).methods['initialize(address,address[])'](pool.address, tokens, { from: owner });

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
        await vault.setAvailableEnabled(true, { from: owner });

        //Setup LP token
        poolToken = await VaultPoolToken.new({ from: owner });

        await (<any> poolToken).methods['initialize(address,string,string)'](
            pool.address, 'VaultSavings', 'VLT', { from: owner });

        await poolToken.addMinter(vaultSavings.address, { from: owner });
        await poolToken.addMinter(vault.address, { from: owner });
        await poolToken.addMinter(defiops, { from: owner });

        //Add liquidity to have some LP tokens minted
        await dai.approve(curveDeposit.address, 1000, { from: owner });
        await usdc.approve(curveDeposit.address, 1000, { from: owner });
        await busd.approve(curveDeposit.address, 1000, { from: owner });
        await usdt.approve(curveDeposit.address, 1000, { from: owner });

        //add into the deposit
        await curveDeposit.add_liquidity(Object.values(initial_liquidity), 0, { from: owner });


        await vaultSavings.registerVault(vault.address, poolToken.address, { from: owner });
        //Preliminary balances
        await dai.transfer(user1, 1000, { from: owner });
        await dai.transfer(user2, 1000, { from: owner });
        await dai.transfer(user3, 1000, { from: owner });

        await usdc.transfer(user1, 1000, { from: owner });
        await usdc.transfer(user2, 1000, { from: owner });
        await usdc.transfer(user3, 1000, { from: owner });

        await busd.transfer(user1, 1000, { from: owner });
        await busd.transfer(user2, 1000, { from: owner });
        await busd.transfer(user3, 1000, { from: owner });

        await usdt.transfer(user1, 1000, { from: owner });
        await usdt.transfer(user2, 1000, { from: owner });
        await usdt.transfer(user3, 1000, { from: owner });

        globalSnap = await Snapshot.create(web3.currentProvider);
    });

    describe('Deposit into the strategy', () => {

        beforeEach(async() => {
            await dai.approve(vaultSavings.address, 100, { from: user1 });
            await usdc.approve(vaultSavings.address, 100, { from: user1 });
            await busd.approve(vaultSavings.address, 100, { from: user1 });
            await usdt.approve(vaultSavings.address, 100, { from: user1 });
        });

        afterEach(async() => await globalSnap.revert());

        it('Deposit', async() => {
            const amounts = { dai: 10, usdc: 15, busd: 5, usdt: 25 };
            const beforeStrategy = {
                balanceOf: {
                    dai: await vaultCurveStrategy.balanceOf.call(dai.address),
                    usdc: await vaultCurveStrategy.balanceOf.call(usdc.address),
                    busd: await vaultCurveStrategy.balanceOf.call(busd.address),
                    usdt: await vaultCurveStrategy.balanceOf.call(usdt.address),
                },
                balanceOfAll: (await vaultCurveStrategy.balanceOfAll.call()).map(x => x.toNumber()),
                poolToken: await poolToken.balanceOf(user1),
            };

            expect(beforeStrategy.balanceOfAll, 'Initial strategy balance should be zero').to.eql([0, 0, 0, 0]);

            await (<VaultSavingsModuleInstance> vaultSavings).methods['deposit(address,address[],uint256[])'](
                vault.address, tokens, Object.values(amounts), { from: user1 });

            await vaultSavings.handleOperatorActions(
                vault.address, vaultCurveStrategy.address, ZERO_ADDRESS, { from: defiops });

            //Tokens are deposited into Y-tokens
            expect((await dai.balanceOf(ydai.address)).toNumber(), 
                "Token (1) is not deposited into strategy").to.equal(amounts.dai + initial_liquidity.dai);
            expect((await usdc.balanceOf(yusdc.address)).toNumber(), 
                "Token (2) is not deposited into strategy").to.equal(amounts.usdc + initial_liquidity.usdc);
            expect((await busd.balanceOf(ybusd.address)).toNumber(), 
                "Token (3) is not deposited into strategy").to.equal(amounts.busd + initial_liquidity.busd);
            expect((await usdt.balanceOf(yusdt.address)).toNumber(), 
                "Token (4) is not deposited into strategy").to.equal(amounts.usdt + initial_liquidity.dai);


            const afterStrategy = {
                balanceOf: {
                    dai: await vaultCurveStrategy.balanceOf.call(dai.address),
                    usdc: await vaultCurveStrategy.balanceOf.call(usdc.address),
                    busd: await vaultCurveStrategy.balanceOf.call(busd.address),
                    usdt: await vaultCurveStrategy.balanceOf.call(usdt.address),
                },
                balanceOfAll: (await vaultCurveStrategy.balanceOfAll.call()).map(x => x.toNumber()),
                tokenAmount: await curveSwap.calc_token_amount(Object.values(amounts), false),
                poolToken: await poolToken.balanceOf(user1),
            };

            expect(afterStrategy.balanceOf.dai.gt(beforeStrategy.balanceOf.dai), 'DAI was not deposited to strategy').to.be.true;
            expect(afterStrategy.balanceOf.usdc.gt(beforeStrategy.balanceOf.usdc), 'USDC was not deposited to strategy').to.be.true;
            expect(afterStrategy.balanceOf.busd.gt(beforeStrategy.balanceOf.busd), 'BUSD was not deposited to strategy').to.be.true;
            expect(afterStrategy.balanceOf.usdt.gt(beforeStrategy.balanceOf.usdt), 'USDT was not deposited to strategy').to.be.true;

            const poolTokenCalc = normalize(amounts.dai, 18) + normalize(amounts.usdc, 6) + normalize(amounts.busd, 6) + normalize(amounts.usdt, 18);
            const poolTokenBalance = await poolToken.balanceOf(user1);

            expect(poolTokenCalc.toString(), "Incorrect number of pool tokens minted").to.equal(poolTokenBalance.toString());
        });

    });

    describe('Withdraw from the strategy', () => {

        let localSnap: Snapshot;
        const amounts = { dai: 10, usdc: 15, busd: 5, usdt: 25 };

        beforeEach(async() => {
            await dai.approve(vaultSavings.address, 100, { from: user1 });
            await usdc.approve(vaultSavings.address, 100, { from: user1 });
            await busd.approve(vaultSavings.address, 100, { from: user1 });
            await usdt.approve(vaultSavings.address, 100, { from: user1 });

            await dai.approve(vaultSavings.address, 100, { from: user2 });
            await usdc.approve(vaultSavings.address, 100, { from: user2 });
            await busd.approve(vaultSavings.address, 100, { from: user2 });
            await usdt.approve(vaultSavings.address, 100, { from: user2 });

            await vaultSavings.setVaultRemainder(vault.address, 1, 0, {from:defiops});
            await vaultSavings.setVaultRemainder(vault.address, 1, 1, {from:defiops});
            await vaultSavings.setVaultRemainder(vault.address, 1, 2, {from:defiops});
            await vaultSavings.setVaultRemainder(vault.address, 1, 3, {from:defiops});

            // Make deposits
            await (<VaultSavingsModuleInstance> vaultSavings).methods['deposit(address,address[],uint256[])'](
                vault.address, tokens, Object.values(amounts), { from: user1 });
            await (<VaultSavingsModuleInstance>vaultSavings).methods['deposit(address,address[],uint256[])'](
                vault.address, tokens,
                [10, 10, 10, 10], { from: user2 });

            await vaultSavings.handleOperatorActions(
                vault.address, vaultCurveStrategy.address, ZERO_ADDRESS, { from: defiops });

            localSnap = await Snapshot.create(web3.currentProvider);
        });

        afterEach(async() => await localSnap.revert());

        it('Withdraw', async() => {
            const beforeBalances = {
                user: {
                    dai: await dai.balanceOf(user1),
                    usdc: await usdc.balanceOf(user1),
                    busd: await busd.balanceOf(user1),
                    usdt: await usdt.balanceOf(user1),
                },
                vault: {
                    dai: await dai.balanceOf(vault.address),
                    usdc: await usdc.balanceOf(vault.address),
                    busd: await busd.balanceOf(vault.address),
                    usdt: await usdt.balanceOf(vault.address),
                },
                strat: {
                    dai: await dai.balanceOf(ydai.address),
                    usdc: await usdc.balanceOf(yusdc.address),
                    busd: await busd.balanceOf(ybusd.address),
                    usdt: await usdt.balanceOf(yusdt.address),
                }
            };

            await vaultSavings.withdraw(vault.address, tokens, Object.values(amounts), false, { from: user1 });
            await vaultSavings.handleOperatorActions(vault.address, vaultCurveStrategy.address, ZERO_ADDRESS,
                { from: defiops });

            const afterBalances = {
                poolToken: await poolToken.balanceOf(user1),
                user: {
                    dai: await dai.balanceOf(user1),
                    usdc: await usdc.balanceOf(user1),
                    busd: await busd.balanceOf(user1),
                    usdt: await usdt.balanceOf(user1),
                },
                vault: {
                    dai: await dai.balanceOf(vault.address),
                    usdc: await usdc.balanceOf(vault.address),
                    busd: await busd.balanceOf(vault.address),
                    usdt: await usdt.balanceOf(vault.address),
                },
                strat: {
                    dai: await dai.balanceOf(ydai.address),
                    usdc: await usdc.balanceOf(yusdc.address),
                    busd: await busd.balanceOf(ybusd.address),
                    usdt: await usdt.balanceOf(yusdt.address),
                }
            };

            expect(beforeBalances.user.dai.toString(), 'User DAI balance should not change')
                .to.equal(afterBalances.user.dai.toString());
            expect(beforeBalances.user.usdc.toString(), 'User USDC balance should not change')
                .to.equal(afterBalances.user.usdc.toString());
            expect(beforeBalances.user.busd.toString(), 'User BUSD balance should not change')
                .to.equal(afterBalances.user.busd.toString());
            expect(beforeBalances.user.usdt.toString(), 'User USDT balance should not change')
                .to.equal(afterBalances.user.usdt.toString());

            expect(afterBalances.poolToken.toNumber(), 'User should have no pool tokens').to.equal(0);

            expect(beforeBalances.strat.dai.sub(afterBalances.strat.dai).toString(), 'DAI not withdrawn from strategy')
                .to.equal(afterBalances.vault.dai.sub(beforeBalances.vault.dai).toString());
            expect(beforeBalances.strat.usdc.sub(afterBalances.strat.usdc).toString(), 'USDC not withdrawn from strategy')
                .to.equal(afterBalances.vault.usdc.sub(beforeBalances.vault.usdc).toString());
            expect(beforeBalances.strat.busd.sub(afterBalances.strat.busd).toString(), 'BUSD not withdrawn from strategy')
                .to.equal(afterBalances.vault.busd.sub(beforeBalances.vault.busd).toString());
            expect(beforeBalances.strat.usdt.sub(afterBalances.strat.usdt).toString(), 'USDT not withdrawn from strategy')
                .to.equal(afterBalances.vault.usdt.sub(beforeBalances.vault.usdt).toString());
                

            const beforeClaim = {
                dai: await dai.balanceOf(user1),
                usdc: await usdc.balanceOf(user1),
                busd: await busd.balanceOf(user1),
                usdt: await usdt.balanceOf(user1)
            };
            await vaultSavings.claimAllRequested(vault.address, {from: user1});
            const afterClaim = {
                dai: await dai.balanceOf(user1),
                usdc: await usdc.balanceOf(user1),
                busd: await busd.balanceOf(user1),
                usdt: await usdt.balanceOf(user1)
            };

            expect(afterClaim.dai.sub(beforeClaim.dai).toNumber(), 'DAI not claimed').to.equal(amounts.dai);
            expect(afterClaim.usdc.sub(beforeClaim.usdc).toNumber(), 'USDC not claimed').to.equal(amounts.usdc);
            expect(afterClaim.busd.sub(beforeClaim.busd).toNumber(), 'BUSD not claimed').to.equal(amounts.busd);
            expect(afterClaim.usdt.sub(beforeClaim.usdt).toNumber(), 'USDT not claimed').to.equal(amounts.usdt);
        });

    });
});
