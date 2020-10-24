import { expect, use } from "chai";
import { ethers, Contract, Wallet } from "ethers";
import { deployContract, MockProvider, solidity } from "ethereum-waffle";

import { expandTo18Decimals } from "./utilities";

import ExchangeRates from "../build/ExchangeRates.json";

use(solidity);

describe("Airdrop", () => {
  let provider: MockProvider;

  let developer: Wallet;
  let alice: Wallet;
  let bob: Wallet;
  let charlie: Wallet;
  let david: Wallet;

  let exchangeRates: Contract;

  beforeEach(async () => {
    provider = new MockProvider({
      ganacheOptions: {
        time: new Date(2020, 0, 1),
      },
    });
    [developer, alice, bob, charlie, david] = provider.getWallets();

    // Alice is oracle
    exchangeRates = await deployContract(developer, ExchangeRates, [
      alice.address,
    ]);
  });

  it("only oracle can set rates", async () => {
    await expect(
      exchangeRates
        .connect(bob)
        .updateRates(
          [ethers.utils.formatBytes32String("sBTC")],
          [expandTo18Decimals(10000)],
          Math.floor(new Date(2020, 0, 1).getTime() / 1000)
        )
    ).to.revertedWith("ExchangeRates: not oracle");

    // Even owner is not allowed
    await expect(
      exchangeRates
        .connect(developer)
        .updateRates(
          [ethers.utils.formatBytes32String("sBTC")],
          [expandTo18Decimals(10000)],
          Math.floor(new Date(2020, 0, 1).getTime() / 1000)
        )
    ).to.revertedWith("ExchangeRates: not oracle");

    // Only oracle can call
    await exchangeRates
      .connect(alice)
      .updateRates(
        [ethers.utils.formatBytes32String("sBTC")],
        [expandTo18Decimals(10000)],
        Math.floor(new Date(2020, 0, 1).getTime() / 1000)
      );
  });

  it("constant sUSD rate", async () => {
    // Rate is already set to 1 without any oracle tx
    expect(
      (
        await exchangeRates.getRateAndTime(
          ethers.utils.formatBytes32String("sUSD")
        )
      ).rate
    ).to.equal(expandTo18Decimals(1));

    // Oracle cannot update sUSD rate
    await expect(
      exchangeRates
        .connect(alice)
        .updateRates(
          [ethers.utils.formatBytes32String("sUSD")],
          [expandTo18Decimals(10000)],
          Math.floor(new Date(2020, 0, 1).getTime() / 1000)
        )
    ).to.revertedWith("ExchangeRates: cannot set sUSD rate");
  });

  it("normal rate update", async () => {
    // Rate is 0 before any update
    expect(
      (
        await exchangeRates.getRateAndTime(
          ethers.utils.formatBytes32String("sBTC")
        )
      ).rate
    ).to.equal(0);

    // sBTC rate updated
    await exchangeRates
      .connect(alice)
      .updateRates(
        [ethers.utils.formatBytes32String("sBTC")],
        [expandTo18Decimals(10000)],
        Math.floor(new Date(2020, 0, 1).getTime() / 1000)
      );

    const newRate = await exchangeRates.getRateAndTime(
      ethers.utils.formatBytes32String("sBTC")
    );
    expect(newRate.rate).to.equal(expandTo18Decimals(10000));
    expect(newRate.time).to.equal(
      Math.floor(new Date(2020, 0, 1).getTime() / 1000)
    );
  });

  it("stale rate update rejected", async () => {
    // sBTC rate updated
    await exchangeRates
      .connect(alice)
      .updateRates(
        [ethers.utils.formatBytes32String("sBTC")],
        [expandTo18Decimals(10000)],
        Math.floor(new Date(2020, 0, 1).getTime() / 1000)
      );

    // Attemp to set rate at older time will fail
    await expect(
      exchangeRates
        .connect(alice)
        .updateRates(
          [ethers.utils.formatBytes32String("sBTC")],
          [expandTo18Decimals(10000)],
          Math.floor(new Date(2020, 0, 1).getTime() / 1000) - 1
        )
    ).to.revertedWith("ExchangeRates: no update");
  });
});
