import {
  DcaModuleInstance,
  FreeErc20Instance,
  FakeUniswapRouterInstance,
  FakeSavingsModuleInstance,
} from "../types/truffle-contracts";

const { BN, ether } = require("@openzeppelin/test-helpers");
const chai = require("chai");
const { expect } = require("chai");
chai.use(require("chai-bn")(BN));

const FreeERC20 = artifacts.require("FreeERC20");
const DCAModule = artifacts.require("DCAModule");
const FakeUniswapRouter = artifacts.require("FakeUniswapRouter");
const FakeSavingsModule = artifacts.require("FakeSavingsModule");

const PERIOD = 86400;

contract("DCAModule", ([bot, osPool, acc1, acc2]) => {
  let usdcInstance: FreeErc20Instance;
  let wbtcInstance: FreeErc20Instance;
  let usdcPoolTokenInstance: FreeErc20Instance;
  let wbtcPoolTokenInstance: FreeErc20Instance;
  let rewardTokenInstance: FreeErc20Instance;

  let dcaModuleInstance: DcaModuleInstance;
  let fakeUniswapRouterInstance: FakeUniswapRouterInstance;
  let fakeSavingsModuleInstance: FakeSavingsModuleInstance;

  beforeEach(async () => {
    // Tokens Deploy
    usdcInstance = FreeERC20.new("USD Coinbase", "USDC", 6, ether("10000"));
    wbtcInstance = FreeERC20.new("Wrapped BTC", "WBTC", 8, ether("10000"));
    usdcPoolTokenInstance = FreeERC20.new(
      "Pool USD Coinbase Token",
      "PUSDC",
      8,
      ether("10000"),
    );
    wbtcPoolTokenInstance = FreeERC20.new(
      "Pool Wrapped BTC",
      "PWBTC",
      8,
      ether("10000"),
    );
    rewardTokenInstance = FreeERC20.new(
      "Reward Token",
      "RWD",
      18,
      ether("10000"),
    );

    // Svaing Deploy
    // @ts-ignore
    fakeSavingsModuleInstance = FakeSavingsModule.new(
      [rewardTokenInstance.address],
      usdcInstance.address,
      await usdcInstance.decimals(),
      usdcPoolTokenInstance.address,
      wbtcInstance.address,
      await wbtcInstance.decimals(),
      wbtcPoolTokenInstance.address,
    );

    // SavigsModule poolToken Fund
    usdcPoolTokenInstance.transfer(
      fakeSavingsModuleInstance.address,
      ether("5000"),
      {
        from: bot,
      },
    );

    wbtcPoolTokenInstance.transfer(
      fakeSavingsModuleInstance.address,
      ether("5000"),
      {
        from: bot,
      },
    );

    // DCA Deploy
    dcaModuleInstance = await DCAModule.new();

    dcaModuleInstance.initialize(
      "DCA Token",
      "DCA",
      osPool,
      // @ts-ignore
      usdcInstance.address,
      [wbtcInstance.address],
      fakeUniswapRouterInstance.address,
      PERIOD,
      bot,
    );
  });

  it("should deposit (new user)", async () => {
    expect().to.be.a.bignumber.that.equals();
  });

  it("should deposit (existing user)", async () => {
    expect().to.be.a.bignumber.that.equals();
  });

  it("should purchase (existing user)", async () => {
    expect().to.be.a.bignumber.that.equals();
  });

  it("should withdraw with reward and yield", async () => {
    expect().to.be.a.bignumber.that.equals();
  });
});
