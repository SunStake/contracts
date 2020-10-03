import { expect, use } from "chai";
import { Contract } from "ethers";
import { deployContract, MockProvider, solidity } from "ethereum-waffle";

import { expandTo18Decimals, expandTo6Decimals, uint256Max } from "./utilities";

import AnyToken from "../build/AnyToken.json";
import SskToken from "../build/SskToken.json";
import AirdropHub from "../build/AirdropHub.json";

use(solidity);

describe("AirdropHub", () => {
  const provider = new MockProvider({
    ganacheOptions: {
      time: new Date(2020, 0, 1),
    },
  });

  const [developer, alice, bob, charlie, david] = provider.getWallets();

  let sunToken: Contract;
  let sskToken: Contract;
  let airdropHub: Contract;

  beforeEach(async () => {
    sunToken = await deployContract(developer, AnyToken, [
      "SunToken", // name
      "SUN", // symbol
      18, // decimals
      expandTo18Decimals(1_000_000), // totalSupply
    ]);
    sskToken = await deployContract(developer, SskToken, []);
    airdropHub = await deployContract(developer, AirdropHub, [
      sunToken.address, // _stakeToken
      sskToken.address, // _airdropToken
    ]);

    // Initial SUN balances
    await sunToken.transfer(alice.address, expandTo18Decimals(10_000));
    await sunToken.transfer(bob.address, expandTo18Decimals(10_000));
    await sunToken.transfer(charlie.address, expandTo18Decimals(10_000));
    await sunToken.transfer(david.address, expandTo18Decimals(10_000));

    // Initial SSK balances
    await sskToken.addMinter(developer.address);
    await sskToken.mint(alice.address, expandTo18Decimals(10_000));
    await sskToken.mint(bob.address, expandTo18Decimals(10_000));
    await sskToken.mint(charlie.address, expandTo18Decimals(10_000));
    await sskToken.mint(david.address, expandTo18Decimals(10_000));
  });

  it("createAirdrop", async () => {
    await sskToken.mint(developer.address, expandTo18Decimals(50_000));
    expect(await sskToken.balanceOf(developer.address)).to.equal(
      expandTo18Decimals(50_000)
    );
    expect(await airdropHub.airdropCount()).to.equal(0);

    await sskToken.approve(airdropHub.address, uint256Max);
    const newAirdropTx = await (
      await airdropHub.createAirdrop(
        expandTo18Decimals(50_000),
        Math.floor(new Date(2020, 0, 2).getTime() / 1000),
        20_00
      )
    ).wait();
    const newAirdropEvent = newAirdropTx.events.find(
      (item) => item.event === "NewAirdrop"
    );
    const newAirdropAddress = newAirdropEvent.args.airdropAddress;

    expect(await sskToken.balanceOf(developer.address)).to.equal(0);
    expect(await sskToken.balanceOf(airdropHub.address)).to.equal(0);
    expect(await sskToken.balanceOf(newAirdropAddress)).to.equal(
      expandTo18Decimals(50_000)
    );

    expect(await airdropHub.airdropCount()).to.equal(1);
    expect(await airdropHub.airdrops(0)).to.equal(newAirdropAddress);
    expect(await airdropHub.airdropMap(newAirdropAddress)).to.equal(true);
  });

  it("onlyAirdrop", async () => {
    await expect(
      airdropHub.registerReferral(alice.address, bob.address)
    ).to.be.revertedWith("AirdropHub: not airdrop");
    await expect(
      airdropHub.addReferralReward(alice.address, 100)
    ).to.be.revertedWith("AirdropHub: not airdrop");
    await expect(
      airdropHub.transferFrom(alice.address, 100)
    ).to.be.revertedWith("AirdropHub: not airdrop");
  });

  it("emergency TRX withdrawal", async () => {
    const devBalanceBefore = await developer.getBalance();

    await alice.sendTransaction({
      from: alice.address,
      to: airdropHub.address,
      value: expandTo6Decimals(100),
    });

    expect(await provider.getBalance(airdropHub.address)).to.equal(
      expandTo6Decimals(100)
    );

    await airdropHub.withdrawTrx(expandTo6Decimals(100), { gasPrice: 0 });

    expect(await provider.getBalance(airdropHub.address)).to.equal(0);
    expect(await developer.getBalance()).to.equal(
      devBalanceBefore.add(expandTo6Decimals(100))
    );
  });

  it("emergency TRC20 withdrawal", async () => {
    expect(await sskToken.balanceOf(developer.address)).to.equal(0);
    expect(await sskToken.balanceOf(airdropHub.address)).to.equal(0);

    await sskToken
      .connect(alice)
      .transfer(airdropHub.address, expandTo18Decimals(100));

    expect(await sskToken.balanceOf(airdropHub.address)).to.equal(
      expandTo18Decimals(100)
    );

    await airdropHub.withdrawTrc20(sskToken.address, expandTo18Decimals(100));
    expect(await sskToken.balanceOf(developer.address)).to.equal(
      expandTo18Decimals(100)
    );
    expect(await sskToken.balanceOf(airdropHub.address)).to.equal(0);
  });
});
