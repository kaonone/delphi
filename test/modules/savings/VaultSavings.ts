import { 
    VaultProtocolStubContract, VaultProtocolStubInstance,
    TestErc20Contract, TestErc20Instance,
    VaultSavingsModuleContract, VaultSavingsModuleInstance,
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
        //The user gets yeild only if he has no on-hold deposits

    });




    describe('Full cycle with the strategy', () => {
        afterEach(async () => {
            await globalSnap.revert();
        });

        it('Full cycle (with CurveFi strategy)', async () => {
            //User1 deposits into the Vault
            //Gets pull tokens

            //User2 deposits into the Vault
            //Gets pull tokens

            //Operator resolves deposits

            //Deposits are on the Curve protocol

            //New deposits

            //Yield from pool is distributed before the new deposit
            //Operator resolves deposits
            
            //Operator checks yield from strategy
            //Yield distribution

            //Withdraw - LP for requests creation

            //Operator resolves withdraw requests

            //User can claim the withdraw
        });

    });
});