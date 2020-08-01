// import {
//   DCAModuleInstance,
//   IUniswapV2Router02Instance,
//   IERC20Instance,
//   PoolInstance,
// } from "../types/truffle-contracts/index";

// const IERC20 = artifacts.require("IERC20");
// const IUniswapV2Router02 = artifacts.require("IUniswapV2Router02");
// const Pool = artifacts.require("Pool");
// const DCAModule = artifacts.require("DCAModule");

// // tslint:disable-next-line:no-var-requires
// const {
//   BN,
//   constants,
//   expectEvent,
//   expectRevert,
//   shouldFail,
//   time,
//   ether,
// } = require("@openzeppelin/test-helpers");
// // tslint:disable-next-line:no-var-requires
// const should = require("chai").should();
// var expect = require("chai").expect;
// const w3random = require("./utils/w3random");
// const expectEqualBN = require("./utils/expectEqualBN");
// const { setTime } = require("./utils/setTime");
// const BN1E18 = new BN("10").pow(new BN(18));

// const PERIOD = 84600;

// contract("DCAModule", ([owner, bot, acc1, acc2, acc3]) => {
//   let poolInstance: PoolInstance;
//   let dcaModuleInstance: DCAModuleInstance;
//   let uniswapRouterInstance: IUniswapV2Router02Instance;
//   let daiInstance: IERC20Instance;
//   let wbtcInstance: IERC20Instance;
//   let wethInstance: IERC20Instance;

//   beforeEach(async () => {
//     uniswapRouterInstance = await IUniswapV2Router02.at(
//       "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D"
//     );

//     const WETH = await uniswapRouterInstance.WETH();

//     daiInstance = await IERC20.at("0x6B175474E89094C44Da98b954EedeAC495271d0F");

//     wbtcInstance = await IERC20.at(
//       "0x6B175474E89094C44Da98b954EedeAC495271d0F"
//     );

//     wethInstance = await IERC20.at(WETH.toString());

//     // Wrap ETH
//     await web3.eth.sendTransaction({
//       from: acc3,
//       to: wethInstance.address,
//       value: ether("40"),
//     });

//     await wethInstance.approve(uniswapRouterInstance.address, ether("10"));

//     // Buy DAI
//     uniswapRouterInstance.swapExactTokensForTokens(
//       ether("10"),
//       ether("0"),
//       [wethInstance.address, daiInstance.address],
//       acc3,
//       ether("1000000000000000000000"),
//       { from: acc3 }
//     );

//     poolInstance = await Pool.new();
//     dcaModuleInstance = await DCAModule.new();

//     await poolInstance.initialize({ from: owner });

//     await dcaModuleInstance.initialize(
//       poolInstance.address,
//       "DCA Token",
//       "DTK",
//       // @ts-ignore
//       daiInstance.address,
//       1,
//       uniswapRouterInstance.address,
//       PERIOD,
//       bot
//     );

//     dcaModuleInstance.setDistributionToken("wbtc", wbtcInstance.address);
//     dcaModuleInstance.setDistributionToken("weth", wethInstance.address);

//     dcaModuleInstance.setDeadline(ether("1000"), { from: bot });

//     await poolInstance.set("dca", dcaModuleInstance.address, true, {
//       from: owner,
//     });

//     daiInstance.transfer(acc1, ether("20"), {
//       from: acc3,
//     });

//     daiInstance.transfer(acc2, ether("20"), {
//       from: acc3,
//     });
//   });

//   // it("should deposit funds and set params", async () => {
//   //   const balance = await wethInstance.balanceOf(acc1);

//   //   console.log({ balance: balance.toString() });
//   // });

//   it("should deposit funds and set params", async () => {
//     // await daiInstance.approve(dcaModuleInstance.address, ether("10"), {
//     //   from: acc1,
//     // });
//     // await dcaModuleInstance.deposit(ether("10"), ether("2"), { from: acc1 });
//     // const tokenId = await dcaModuleInstance.getTokenIdByAddress(acc1);
//     // expect(
//     //   await dcaModuleInstance.getAccountBalance(tokenId, daiInstance.address)
//     // ).to.be.a.bignumber.that.equals(ether("10"));
//     // expect(
//     //   await dcaModuleInstance.getAccountBuyAmount(tokenId)
//     // ).to.be.a.bignumber.that.equals(ether("2"));
//     // expect(
//     //   await dcaModuleInstance.globalPeriodBuyAmount()
//     // ).to.be.a.bignumber.that.equals(ether("2"));
//     // expect(
//     //   await dcaModuleInstance.getAccountLastRemovalPointIndex(tokenId)
//     // ).to.be.a.bignumber.that.equals(new BN("4"));
//     // expect(
//     //   await daiInstance.balanceOf(dcaModuleInstance.address)
//     // ).to.be.a.bignumber.that.equals(ether("10"));
//     //
//     // await daiInstance.approve(dcaModuleInstance.address, ether("10"), {
//     //   from: acc1,
//     // });
//     // await dcaModuleInstance.deposit(ether("10"), ether("4"), { from: acc1 });
//     // expect(
//     //   await dcaModuleInstance.getAccountBalance(tokenId, daiInstance.address)
//     // ).to.be.a.bignumber.that.equals(ether("20"));
//     // expect(
//     //   await dcaModuleInstance.getAccountBuyAmount(tokenId)
//     // ).to.be.a.bignumber.that.equals(ether("4"));
//     // expect(
//     //   await dcaModuleInstance.globalPeriodBuyAmount()
//     // ).to.be.a.bignumber.that.equals(ether("4"));
//     // expect(
//     //   await dcaModuleInstance.getAccountLastRemovalPointIndex(tokenId)
//     // ).to.be.a.bignumber.that.equals(new BN("4"));
//     // expect(
//     //   await daiInstance.balanceOf(dcaModuleInstance.address)
//     // ).to.be.a.bignumber.that.equals(ether("20"));
//   });
// });
