import { 
    VaultProtocolStubContract, VaultProtocolStubInstance,
    TestErc20Contract, TestErc20Instance,
    CurveFiStablecoinStrategyContract, CurveFiStablecoinStrategyInstance
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

const VaultProtocol = artifacts.require("VaultProtocolStub");

contract("VaultSavings", async ([_, owner, user1, user2, user3, pool, defiops, protocolStub, ...otherAccounts]) => {
    let globalSnap: Snapshot;
    let vaultProtocol: VaultProtocolStubInstance;
    let dai: TestErc20Instance;
    let usdc: TestErc20Instance;
    let busd: TestErc20Instance;


    before(async () => {
        vaultProtocol = await VaultProtocol.new({from:owner});
        await (<any> vaultProtocol).methods['initialize(address)'](pool, {from: owner});
        await vaultProtocol.addDefiOperator(defiops, {from:owner});
        
        //Deposit token 1
        dai = await ERC20.new({from:owner});
        await dai.initialize("DAI", "DAI", 18, {from:owner})
        //Deposit token 2
        usdc = await ERC20.new({from:owner});
        await usdc.initialize("USDC", "USDC", 18, {from:owner})
        //Deposit token 3
        busd = await ERC20.new({from:owner});
        await busd.initialize("BUSD", "BUSD", 18, {from:owner})

        await dai.transfer(user1, 1000, {from:owner});
        await dai.transfer(user2, 1000, {from:owner});
        await dai.transfer(user3, 1000, {from:owner});

        await usdc.transfer(user1, 1000, {from:owner});
        await usdc.transfer(user2, 1000, {from:owner});
        await usdc.transfer(user3, 1000, {from:owner});

        await busd.transfer(user1, 1000, {from:owner});
        await busd.transfer(user2, 1000, {from:owner});
        await busd.transfer(user3, 1000, {from:owner});

        await vaultProtocol.registerTokens([dai.address, usdc.address, busd.address], {from: defiops})
        await vaultProtocol.setProtocol(protocolStub, {from: defiops});

        globalSnap = await Snapshot.create(web3.currentProvider);
    });


    describe('Deposit into the vault', () => {
    });

    describe('Yield distribution', () => {
        // 1) Operator deposits stablecoins into the protocol
        //      Yield is earned
        //      Operator checks pool yield

        // 2) Strategy yield
        //      Operator provides CRV reward claim
        //      Operator swaps CRV to stablecoin on Uniswap
        //      Operator distributes stablecoin yield

    });
});