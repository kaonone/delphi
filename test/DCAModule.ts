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

contract("DCAModule", ([owner, bot, acc1, acc2]) => {
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

    await dcaModuleInstance.initialize(
      poolInstance.address,
      "DCA Token",
      "DTK",
      // @ts-ignore
      usdcInstance.address,
      1,
      fakeUniswapRouterInstance.address,
      PERIOD,
      bot
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

  it("should purchase and push distribution", async () => {
    await usdcInstance.approve(dcaModuleInstance.address, ether("10"), {
      from: acc1,
    });

    await usdcInstance.approve(dcaModuleInstance.address, ether("10"), {
      from: acc2,
    });

    await dcaModuleInstance.deposit(ether("10"), ether("2"), { from: acc1 });
    await dcaModuleInstance.deposit(ether("10"), ether("2"), { from: acc2 });

    setTime(PERIOD);

    await dcaModuleInstance.purchase({ from: bot });

    expect(
      await dcaModuleInstance.getDistributionsNumber()
    ).to.be.a.bignumber.that.equals(new BN("2"));

    expect(
      await dcaModuleInstance.getDistributionAmount(0)
    ).to.be.a.bignumber.that.equals(ether("2"));

    expect(
      await dcaModuleInstance.getDistributionTotalSupply(0)
    ).to.be.a.bignumber.that.equals(ether("2"));

    expect(
      await dcaModuleInstance.getDistributionAmount(1)
    ).to.be.a.bignumber.that.equals(ether("2"));

    expect(
      await dcaModuleInstance.getDistributionTotalSupply(1)
    ).to.be.a.bignumber.that.equals(ether("2"));
  });

  it("should claim distributions", async () => {
    await usdcInstance.approve(dcaModuleInstance.address, ether("10"), {
      from: acc1,
    });

    await usdcInstance.approve(dcaModuleInstance.address, ether("10"), {
      from: acc2,
    });

    await dcaModuleInstance.deposit(ether("10"), ether("2"), { from: acc1 });
    await dcaModuleInstance.deposit(ether("10"), ether("2"), { from: acc2 });

    setTime(PERIOD);

    await dcaModuleInstance.purchase({ from: bot });

    await dcaModuleInstance.checkDistributions({ from: acc1 });
    await dcaModuleInstance.checkDistributions({ from: acc2 });

    const tokenIdAcc1 = await dcaModuleInstance.getTokenIdByAddress(acc1);
    const tokenIdAcc2 = await dcaModuleInstance.getTokenIdByAddress(acc2);

    expect(
      await dcaModuleInstance.getAccountBalance(
        tokenIdAcc1,
        wbtcInstance.address
      )
    ).to.be.a.bignumber.that.equals(ether("1"));

    expect(
      await dcaModuleInstance.getAccountBalance(
        tokenIdAcc1,
        wethInstance.address
      )
    ).to.be.a.bignumber.that.equals(ether("1"));

    expect(
      await dcaModuleInstance.getAccountBalance(
        tokenIdAcc2,
        wbtcInstance.address
      )
    ).to.be.a.bignumber.that.equals(ether("1"));

    expect(
      await dcaModuleInstance.getAccountBalance(
        tokenIdAcc2,
        wethInstance.address
      )
    ).to.be.a.bignumber.that.equals(ether("1"));
  });

  it("should withdraw `in` token (USDC)", async () => {
    await usdcInstance.approve(dcaModuleInstance.address, ether("10"), {
      from: acc1,
    });

    await usdcInstance.approve(dcaModuleInstance.address, ether("10"), {
      from: acc2,
    });

    await dcaModuleInstance.deposit(ether("10"), ether("2"), { from: acc1 });
    await dcaModuleInstance.deposit(ether("10"), ether("2"), { from: acc2 });

    setTime(PERIOD);

    await dcaModuleInstance.purchase({ from: bot });

    const usdcBeforeBalanceAcc1 = await usdcInstance.balanceOf(acc1);
    const usdcBeforeBalanceAcc2 = await usdcInstance.balanceOf(acc2);

    await dcaModuleInstance.withdraw(ether("8"), usdcInstance.address, {
      from: acc1,
    });

    await dcaModuleInstance.withdraw(ether("8"), usdcInstance.address, {
      from: acc2,
    });

    const usdcAfterBalanceAcc1 = await usdcInstance.balanceOf(acc1);
    const usdcAfterBalanceAcc2 = await usdcInstance.balanceOf(acc2);

    expect(usdcAfterBalanceAcc1).to.be.a.bignumber.that.equals(
      usdcBeforeBalanceAcc1.add(ether("8"))
    );

    expect(usdcAfterBalanceAcc2).to.be.a.bignumber.that.equals(
      usdcBeforeBalanceAcc2.add(ether("8"))
    );

    const tokenIdAcc1 = await dcaModuleInstance.getTokenIdByAddress(acc1);
    const tokenIdAcc2 = await dcaModuleInstance.getTokenIdByAddress(acc2);

    expect(
      await dcaModuleInstance.getAccountBalance(
        tokenIdAcc1,
        wbtcInstance.address
      )
    ).to.be.a.bignumber.that.equals(ether("1"));

    expect(
      await dcaModuleInstance.getAccountBalance(
        tokenIdAcc1,
        wethInstance.address
      )
    ).to.be.a.bignumber.that.equals(ether("1"));

    expect(
      await dcaModuleInstance.getAccountBalance(
        tokenIdAcc2,
        wbtcInstance.address
      )
    ).to.be.a.bignumber.that.equals(ether("1"));

    expect(
      await dcaModuleInstance.getAccountBalance(
        tokenIdAcc2,
        wethInstance.address
      )
    ).to.be.a.bignumber.that.equals(ether("1"));
  });

  it("should withdraw `out` token (WBTC)", async () => {
    await usdcInstance.approve(dcaModuleInstance.address, ether("10"), {
      from: acc1,
    });

    await usdcInstance.approve(dcaModuleInstance.address, ether("10"), {
      from: acc2,
    });

    await dcaModuleInstance.deposit(ether("10"), ether("2"), { from: acc1 });
    await dcaModuleInstance.deposit(ether("10"), ether("2"), { from: acc2 });

    setTime(PERIOD);

    await dcaModuleInstance.purchase({ from: bot });

    const wbtcBeforeBalanceAcc1 = await wbtcInstance.balanceOf(acc1);
    const wbtcBeforeBalanceAcc2 = await wbtcInstance.balanceOf(acc2);

    await dcaModuleInstance.withdraw(ether("1"), wbtcInstance.address, {
      from: acc1,
    });

    await dcaModuleInstance.withdraw(ether("1"), wbtcInstance.address, {
      from: acc2,
    });

    const wbtcAfterBalanceAcc1 = await wbtcInstance.balanceOf(acc1);
    const wbtcAfterBalanceAcc2 = await wbtcInstance.balanceOf(acc2);

    expect(wbtcAfterBalanceAcc1).to.be.a.bignumber.that.equals(
      wbtcBeforeBalanceAcc1.add(ether("1"))
    );

    expect(wbtcAfterBalanceAcc2).to.be.a.bignumber.that.equals(
      wbtcBeforeBalanceAcc2.add(ether("1"))
    );

    const tokenIdAcc1 = await dcaModuleInstance.getTokenIdByAddress(acc1);
    const tokenIdAcc2 = await dcaModuleInstance.getTokenIdByAddress(acc2);

    expect(
      await dcaModuleInstance.getAccountBalance(
        tokenIdAcc1,
        wbtcInstance.address
      )
    ).to.be.a.bignumber.that.equals(ether("0"));

    expect(
      await dcaModuleInstance.getAccountBalance(
        tokenIdAcc1,
        wethInstance.address
      )
    ).to.be.a.bignumber.that.equals(ether("1"));

    expect(
      await dcaModuleInstance.getAccountBalance(
        tokenIdAcc2,
        wbtcInstance.address
      )
    ).to.be.a.bignumber.that.equals(ether("0"));

    expect(
      await dcaModuleInstance.getAccountBalance(
        tokenIdAcc2,
        wethInstance.address
      )
    ).to.be.a.bignumber.that.equals(ether("1"));
  });

  it("should withdraw `out` token (WETH)", async () => {
    await usdcInstance.approve(dcaModuleInstance.address, ether("10"), {
      from: acc1,
    });

    await usdcInstance.approve(dcaModuleInstance.address, ether("10"), {
      from: acc2,
    });

    await dcaModuleInstance.deposit(ether("10"), ether("2"), { from: acc1 });
    await dcaModuleInstance.deposit(ether("10"), ether("2"), { from: acc2 });

    setTime(PERIOD);

    await dcaModuleInstance.purchase({ from: bot });

    const wethBeforeBalanceAcc1 = await wethInstance.balanceOf(acc1);
    const wethBeforeBalanceAcc2 = await wethInstance.balanceOf(acc2);

    await dcaModuleInstance.withdraw(ether("1"), wethInstance.address, {
      from: acc1,
    });

    await dcaModuleInstance.withdraw(ether("1"), wethInstance.address, {
      from: acc2,
    });

    const wethAfterBalanceAcc1 = await wethInstance.balanceOf(acc1);
    const wethAfterBalanceAcc2 = await wethInstance.balanceOf(acc2);

    expect(wethAfterBalanceAcc1).to.be.a.bignumber.that.equals(
      wethBeforeBalanceAcc1.add(ether("1"))
    );

    expect(wethAfterBalanceAcc2).to.be.a.bignumber.that.equals(
      wethBeforeBalanceAcc2.add(ether("1"))
    );

    const tokenIdAcc1 = await dcaModuleInstance.getTokenIdByAddress(acc1);
    const tokenIdAcc2 = await dcaModuleInstance.getTokenIdByAddress(acc2);

    expect(
      await dcaModuleInstance.getAccountBalance(
        tokenIdAcc1,
        wbtcInstance.address
      )
    ).to.be.a.bignumber.that.equals(ether("1"));

    expect(
      await dcaModuleInstance.getAccountBalance(
        tokenIdAcc1,
        wethInstance.address
      )
    ).to.be.a.bignumber.that.equals(ether("0"));

    expect(
      await dcaModuleInstance.getAccountBalance(
        tokenIdAcc2,
        wbtcInstance.address
      )
    ).to.be.a.bignumber.that.equals(ether("1"));

    expect(
      await dcaModuleInstance.getAccountBalance(
        tokenIdAcc2,
        wethInstance.address
      )
    ).to.be.a.bignumber.that.equals(ether("0"));
  });
});
