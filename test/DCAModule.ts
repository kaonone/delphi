import {
  DCAModuleInstance,
  FakeUniswapRouterInstance,
  FreeERC20Instance,
  PoolInstance,
} from "../types/truffle-contracts/index";

const FreeERC20 = artifacts.require("FreeERC20");
const FakeUniswapRouter = artifacts.require("FakeUniswapRouter");
const Pool = artifacts.require("Pool");
const DCAModule = artifacts.require("DCAModule");

// tslint:disable-next-line:no-var-requires
const {
  BN,
  constants,
  expectEvent,
  expectRevert,
  shouldFail,
  time,
  ether,
} = require("@openzeppelin/test-helpers");
// tslint:disable-next-line:no-var-requires
const should = require("chai").should();
var expect = require("chai").expect;
const w3random = require("./utils/w3random");
const expectEqualBN = require("./utils/expectEqualBN");
const { setTime } = require("./utils/setTime");
const BN1E18 = new BN("10").pow(new BN(18));

const PERIOD = 84600;

contract("DCAModule", ([owner, acc1, acc2]) => {
  let poolInstance: PoolInstance;
  let dcaModuleInstance: DCAModuleInstance;
  let fakeUniswapRouterInstance: FakeUniswapRouterInstance;
  let usdcInstance: FreeERC20Instance;
  let wbtcInstance: FreeERC20Instance;
  let wethInstance: FreeERC20Instance;

  beforeEach(async () => {
    usdcInstance = await FreeERC20.new();
    wbtcInstance = await FreeERC20.new();
    wethInstance = await FreeERC20.new();

    fakeUniswapRouterInstance = await FakeUniswapRouter.new();

    poolInstance = await Pool.new();
    dcaModuleInstance = await DCAModule.new();

    await poolInstance.initialize({ from: owner });

    await dcaModuleInstance.initialize_(
      poolInstance.address,
      "DCA Token",
      "DTK",
      usdcInstance.address,
      1,
      fakeUniswapRouterInstance.address,
      PERIOD
    );

    dcaModuleInstance.setDistributionToken("wbtc", wbtcInstance.address);
    dcaModuleInstance.setDistributionToken("weth", wethInstance.address);

    await poolInstance.set("dca", dcaModuleInstance.address, true, {
      from: owner,
    });

    usdcInstance.transfer(acc1, ether("100"), {
      from: owner,
    });

    usdcInstance.transfer(acc2, ether("100"), {
      from: owner,
    });

    wbtcInstance.transfer(fakeUniswapRouterInstance.address, ether("1000"), {
      from: owner,
    });

    wethInstance.transfer(fakeUniswapRouterInstance.address, ether("1000"), {
      from: owner,
    });
  });

  it("should deposit funds and set params", async () => {
    await usdcInstance.approve(dcaModuleInstance.address, ether("10"), {
      from: acc1,
    });

    await dcaModuleInstance.deposit(ether("10"), ether("2"), { from: acc1 });

    const tokenId = await dcaModuleInstance.getTokenIdByAddress(acc1);

    expect(
      await dcaModuleInstance.getAccountBalance(tokenId, usdcInstance.address)
    ).to.be.a.bignumber.that.equals(ether("10"));

    expect(
      await dcaModuleInstance.getAccountBuyAmount(tokenId)
    ).to.be.a.bignumber.that.equals(ether("2"));

    expect(
      await dcaModuleInstance.globalPeriodBuyAmount()
    ).to.be.a.bignumber.that.equals(ether("2"));

    expect(
      await dcaModuleInstance.getAccountLastRemovalPointIndex(tokenId)
    ).to.be.a.bignumber.that.equals(new BN("4"));

    expect(
      await usdcInstance.balanceOf(dcaModuleInstance.address)
    ).to.be.a.bignumber.that.equals(ether("10"));

    //

    await usdcInstance.approve(dcaModuleInstance.address, ether("10"), {
      from: acc1,
    });

    await dcaModuleInstance.deposit(ether("10"), ether("4"), { from: acc1 });

    expect(
      await dcaModuleInstance.getAccountBalance(tokenId, usdcInstance.address)
    ).to.be.a.bignumber.that.equals(ether("20"));

    expect(
      await dcaModuleInstance.getAccountBuyAmount(tokenId)
    ).to.be.a.bignumber.that.equals(ether("4"));

    expect(
      await dcaModuleInstance.globalPeriodBuyAmount()
    ).to.be.a.bignumber.that.equals(ether("4"));

    expect(
      await dcaModuleInstance.getAccountLastRemovalPointIndex(tokenId)
    ).to.be.a.bignumber.that.equals(new BN("4"));

    expect(
      await usdcInstance.balanceOf(dcaModuleInstance.address)
    ).to.be.a.bignumber.that.equals(ether("20"));
  });

  it("should purchase", async () => {
    await usdcInstance.approve(dcaModuleInstance.address, ether("10"), {
      from: acc1,
    });

    await usdcInstance.approve(dcaModuleInstance.address, ether("10"), {
      from: acc2,
    });

    await dcaModuleInstance.deposit(ether("10"), ether("2"), { from: acc1 });
    // await dcaModuleInstance.deposit(ether("10"), ether("2"), { from: acc2 });

    setTime(PERIOD);

    await dcaModuleInstance.purchase();

    // const dAmount0 = await dcaModuleInstance.getDistributionAmount(0);
    // const sAmount0 = await dcaModuleInstance.getDistributionTotalSupply(0);

    // console.log({
    //   dAmount0: dAmount0.toString(),
    //   sAmount0: sAmount0.toString(),
    // });

    const dTokenAddress = await dcaModuleInstance.getDistributionTokenAddress(
      0
    );

    console.log({ dTokenAddress });

    await dcaModuleInstance.checkDistributions({ from: acc1 });

    const tokenIdAcc1 = await dcaModuleInstance.getTokenIdByAddress(acc1);

    const accountLastDist = await dcaModuleInstance.getAccountLastDistributionIndex(
      tokenIdAcc1
    );

    console.log({ accountLastDist: accountLastDist.toString() });

    const balanceBTC = await dcaModuleInstance.getAccountBalance(
      tokenIdAcc1,
      wbtcInstance.address
    );

    const balanceETH = await dcaModuleInstance.getAccountBalance(
      tokenIdAcc1,
      wethInstance.address
    );

    console.log({
      balanceBTC: balanceBTC.toString(),
      balanceETH: balanceETH.toString(),
    });

    expect(
      await dcaModuleInstance.getDistributionsNumber()
    ).to.be.a.bignumber.that.equals(new BN("2"));
  });
});
