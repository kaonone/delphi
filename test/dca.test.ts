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

// @ts-ignore
const FreeERC20 = artifacts.require("FreeERC20");
const DCAModule = artifacts.require("DCAModule");
const FakeUniswapRouter = artifacts.require("FakeUniswapRouter");
const FakeSavingsModule = artifacts.require("FakeSavingsModule");

const PERIOD = 86400;

contract("DCAModule", ([bot, osPool, protocol, acc1, acc2]) => {
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
    // @ts-ignore
    usdcInstance = await FreeERC20.new(
      "USD Coinbase",
      "USDC",
      6,
      new BN(10000e6)
    );
    // @ts-ignore
    wbtcInstance = await FreeERC20.new(
      "Wrapped BTC",
      "WBTC",
      8,
      new BN(10000e8)
    );

    // @ts-ignore
    usdcPoolTokenInstance = await FreeERC20.new(
      "Pool USD Coinbase Token",
      "PUSDC",
      8,
      ether("10000")
    );

    // @ts-ignore
    wbtcPoolTokenInstance = await FreeERC20.new(
      "Pool Wrapped BTC",
      "PWBTC",
      8,
      ether("10000")
    );

    // @ts-ignore
    rewardTokenInstance = await FreeERC20.new(
      "Reward Token",
      "RWD",
      18,
      ether("10000")
    );

    // Uniswap Deploy
    fakeUniswapRouterInstance = await FakeUniswapRouter.new();

    // Svaing Deploy
    fakeSavingsModuleInstance = await FakeSavingsModule.new(
      [rewardTokenInstance.address],
      usdcInstance.address,
      6,
      usdcPoolTokenInstance.address,
      wbtcInstance.address,
      8,
      wbtcPoolTokenInstance.address
    );

    // SavigsModule poolToken Fund
    await usdcPoolTokenInstance.transfer(
      fakeSavingsModuleInstance.address,
      ether("5000"),
      {
        from: bot,
      }
    );

    await wbtcPoolTokenInstance.transfer(
      fakeSavingsModuleInstance.address,
      ether("5000"),
      {
        from: bot,
      }
    );

    await rewardTokenInstance.transfer(
      fakeSavingsModuleInstance.address,
      ether("5000"),
      {
        from: bot,
      }
    );

    // USDC Fund
    await wbtcInstance.transfer(
      fakeUniswapRouterInstance.address,
      new BN(5000e8),
      {
        from: bot,
      }
    );

    await usdcInstance.transfer(acc1, new BN(5000e6), {
      from: bot,
    });

    await usdcInstance.transfer(acc2, new BN(5000e6), {
      from: bot,
    });

    // DCA Deploy
    // @ts-ignore
    dcaModuleInstance = await DCAModule.new();

    await dcaModuleInstance.initialize(
      "DCA Token",
      "DCA",
      osPool,
      // @ts-ignore
      usdcInstance.address,
      [wbtcInstance.address],
      fakeUniswapRouterInstance.address,
      PERIOD,
      bot
    );

    // Set Token Data

    // USDC
    await dcaModuleInstance.setTokenData(
      usdcInstance.address,
      await usdcInstance.decimals(),
      fakeSavingsModuleInstance.address,
      protocol,
      usdcPoolTokenInstance.address
    );

    // WBTC
    await dcaModuleInstance.setTokenData(
      wbtcInstance.address,
      await wbtcInstance.decimals(),
      fakeSavingsModuleInstance.address,
      protocol,
      wbtcPoolTokenInstance.address
    );

    // Reward Token
    await dcaModuleInstance.setTokenData(
      rewardTokenInstance.address,
      await rewardTokenInstance.decimals(),
      fakeSavingsModuleInstance.address,
      protocol,
      rewardTokenInstance.address
    );
  });

  // it("should deposit (new user)", async () => {
  //   await usdcInstance.approve(dcaModuleInstance.address, new BN(500e6), {
  //     from: acc1,
  //   });

  //   await dcaModuleInstance.deposit(new BN(500e6), new BN(100e6), {
  //     from: acc1,
  //   });

  //   const tokenId = await dcaModuleInstance.getTokenIdByAddress(acc1);

  //   expect(
  //     await dcaModuleInstance.getAccountBlance(tokenId, usdcInstance.address),
  //   ).to.be.a.bignumber.that.equals(new BN(500e6));

  //   const [buyAmount] = await dcaModuleInstance._accountOf(tokenId);

  //   expect(buyAmount).to.be.a.bignumber.that.equals(new BN(100e6));
  // });

  it("should deposit (existing user)", async () => {
    await usdcInstance.approve(dcaModuleInstance.address, new BN(1000e6), {
      from: acc1,
    });

    await dcaModuleInstance.deposit(new BN(500e6), new BN(100e6), {
      from: acc1,
    });

    await dcaModuleInstance.deposit(new BN(500e6), new BN(200e6), {
      from: acc1,
    });

    // const tokenId = await dcaModuleInstance.getTokenIdByAddress(acc1);

    // expect(
    //   await dcaModuleInstance.getAccountBlance(tokenId, usdcInstance.address),
    // ).to.be.a.bignumber.that.equals(new BN(1000e6));

    // const [buyAmount] = await dcaModuleInstance._accountOf(tokenId);

    // expect(buyAmount).to.be.a.bignumber.that.equals(new BN(200e6));
  });
});
