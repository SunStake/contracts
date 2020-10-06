import { expect, use } from "chai";
import { Contract, Wallet } from "ethers";
import { deployContract, MockProvider, solidity } from "ethereum-waffle";

import {
  expandTo18Decimals,
  expandTo6Decimals,
  mineBlock,
  uint256Max,
  zeroAddress,
} from "./utilities";

import AnyToken from "../build/AnyToken.json";
import SskToken from "../build/SskToken.json";
import AirdropHub from "../build/AirdropHub.json";
import Airdrop from "../build/Airdrop.json";

use(solidity);

describe("Airdrop", () => {
  let provider: MockProvider;

  let developer: Wallet;
  let alice: Wallet;
  let bob: Wallet;
  let charlie: Wallet;
  let david: Wallet;

  let sunToken: Contract;
  let sskToken: Contract;
  let airdropHub: Contract;
  let airdrop: Contract;

  beforeEach(async () => {
    provider = new MockProvider({
      ganacheOptions: {
        time: new Date(2020, 0, 1),
      },
    });
    [developer, alice, bob, charlie, david] = provider.getWallets();

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

    // Initial dev SSK balance
    await sskToken.addMinter(developer.address);
    await sskToken.mint(developer.address, expandTo18Decimals(50_000));

    // Token spending approval
    await sskToken.connect(developer).approve(airdropHub.address, uint256Max);
    await sunToken.connect(alice).approve(airdropHub.address, uint256Max);
    await sunToken.connect(bob).approve(airdropHub.address, uint256Max);
    await sunToken.connect(charlie).approve(airdropHub.address, uint256Max);
    await sunToken.connect(david).approve(airdropHub.address, uint256Max);

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

    airdrop = new Contract(newAirdropAddress, Airdrop.abi, provider);
  });

  it("emergency TRX withdrawal", async () => {
    const devBalanceBefore = await developer.getBalance();

    await alice.sendTransaction({
      from: alice.address,
      to: airdrop.address,
      value: expandTo6Decimals(100),
    });

    expect(await provider.getBalance(airdrop.address)).to.equal(
      expandTo6Decimals(100)
    );

    await airdrop
      .connect(developer)
      .withdrawTrx(expandTo6Decimals(100), { gasPrice: 0 });

    expect(await provider.getBalance(airdrop.address)).to.equal(0);
    expect(await developer.getBalance()).to.equal(
      devBalanceBefore.add(expandTo6Decimals(100))
    );
  });

  it("emergency TRC20 withdrawal", async () => {
    const trashToken = await deployContract(developer, AnyToken, [
      "TrashToken", // name
      "TRASH", // symbol
      18, // decimals
      expandTo18Decimals(100), // totalSupply
    ]);

    expect(await trashToken.balanceOf(developer.address)).to.equal(
      expandTo18Decimals(100)
    );
    expect(await trashToken.balanceOf(airdrop.address)).to.equal(0);

    // Token accidentally sent to airdrop contract
    await trashToken
      .connect(developer)
      .transfer(airdrop.address, expandTo18Decimals(100));

    expect(await trashToken.balanceOf(developer.address)).to.equal(0);
    expect(await trashToken.balanceOf(airdrop.address)).to.equal(
      expandTo18Decimals(100)
    );

    // Can successfully withdraw as no one staked just yet
    await airdrop
      .connect(developer)
      .withdrawTrc20(trashToken.address, expandTo18Decimals(40));
    expect(await trashToken.balanceOf(developer.address)).to.equal(
      expandTo18Decimals(40)
    );
    expect(await trashToken.balanceOf(airdrop.address)).to.equal(
      expandTo18Decimals(60)
    );

    // Cannot withdraw after someone stakes
    await airdrop
      .connect(alice)
      ["stake(uint256,address)"](expandTo18Decimals(200), zeroAddress);
    await expect(
      airdrop
        .connect(developer)
        .withdrawTrc20(trashToken.address, expandTo18Decimals(60))
    ).to.revertedWith("Airdrop: not zero staker");

    // Can withdraw again after unstake
    await airdrop.connect(alice)["unstake()"]();
    await airdrop
      .connect(developer)
      .withdrawTrc20(trashToken.address, expandTo18Decimals(60));

    expect(await trashToken.balanceOf(developer.address)).to.equal(
      expandTo18Decimals(100)
    );
    expect(await trashToken.balanceOf(airdrop.address)).to.equal(0);
  });

  it("cannot stake after snapshot", async () => {
    // Can stake normally
    await expect(
      airdrop
        .connect(alice)
        ["stake(uint256,address)"](expandTo18Decimals(200), zeroAddress)
    )
      .to.emit(airdrop, "Staked")
      .withArgs(alice.address, expandTo18Decimals(200));

    // Cannot stake after snapshot
    await mineBlock(provider, 2 * 24 * 3600);
    await expect(
      airdrop
        .connect(alice)
        ["stake(uint256,address)"](expandTo18Decimals(200), zeroAddress)
    ).to.be.revertedWith("Airdrop: ended");
  });

  it("staker count & staked amount tracking", async () => {
    expect(await airdrop.currentStakerCount()).to.equal(0);
    expect(await airdrop.totalStakedAmount()).to.equal(0);

    // Alice stakes 200
    await airdrop
      .connect(alice)
      ["stake(uint256,address)"](expandTo18Decimals(200), zeroAddress);
    expect(await airdrop.currentStakerCount()).to.equal(1);
    expect(await airdrop.totalStakedAmount()).to.equal(expandTo18Decimals(200));

    // Bob stakes 300
    await airdrop
      .connect(bob)
      ["stake(uint256,address)"](expandTo18Decimals(300), zeroAddress);
    expect(await airdrop.currentStakerCount()).to.equal(2);
    expect(await airdrop.totalStakedAmount()).to.equal(expandTo18Decimals(500));

    // Alice unstakes half
    await airdrop.connect(alice)["unstake(uint256)"](expandTo18Decimals(100));
    expect(await airdrop.currentStakerCount()).to.equal(2);
    expect(await airdrop.totalStakedAmount()).to.equal(expandTo18Decimals(400));

    // Bob unstakes all
    await airdrop.connect(bob)["unstake(uint256)"](expandTo18Decimals(300));
    expect(await airdrop.currentStakerCount()).to.equal(1);
    expect(await airdrop.totalStakedAmount()).to.equal(expandTo18Decimals(100));

    // Alice unstakes all
    await airdrop.connect(alice)["unstake()"]();
    expect(await airdrop.currentStakerCount()).to.equal(0);
    expect(await airdrop.totalStakedAmount()).to.equal(0);
  });

  it("unstake before snapshot", async () => {
    expect(await sskToken.balanceOf(alice.address)).to.equal(0);
    expect(await sunToken.balanceOf(alice.address)).to.equal(
      expandTo18Decimals(10000)
    );

    await expect(
      airdrop
        .connect(alice)
        ["stake(uint256,address)"](expandTo18Decimals(200), zeroAddress)
    )
      .to.emit(sunToken, "Transfer")
      .withArgs(alice.address, airdrop.address, expandTo18Decimals(200))
      .to.emit(airdrop, "Staked")
      .withArgs(alice.address, expandTo18Decimals(200));

    expect(await sskToken.balanceOf(alice.address)).to.equal(0);
    expect(await sunToken.balanceOf(alice.address)).to.equal(
      expandTo18Decimals(9800)
    );

    await expect(airdrop.connect(alice)["unstake()"]())
      .to.emit(sunToken, "Transfer")
      .withArgs(airdrop.address, alice.address, expandTo18Decimals(200))
      .to.emit(airdrop, "Unstaked")
      .withArgs(alice.address, expandTo18Decimals(200))
      .to.not.emit(airdrop, "AirdropReward");

    expect(await sskToken.balanceOf(alice.address)).to.equal(0);
    expect(await sunToken.balanceOf(alice.address)).to.equal(
      expandTo18Decimals(10000)
    );
  });

  it("unstake after snapshot", async () => {
    expect(await sskToken.balanceOf(alice.address)).to.equal(0);
    expect(await sunToken.balanceOf(alice.address)).to.equal(
      expandTo18Decimals(10000)
    );
    expect(await sskToken.balanceOf(airdrop.address)).to.equal(
      expandTo18Decimals(50000)
    );

    await airdrop
      .connect(alice)
      ["stake(uint256,address)"](expandTo18Decimals(200), zeroAddress);

    expect(await sskToken.balanceOf(alice.address)).to.equal(0);
    expect(await sunToken.balanceOf(alice.address)).to.equal(
      expandTo18Decimals(9800)
    );
    expect(await sskToken.balanceOf(airdrop.address)).to.equal(
      expandTo18Decimals(50000)
    );

    // Snapshot
    await mineBlock(provider, 2 * 24 * 3600);

    // Cannot partially unstake after snapshot
    await expect(
      airdrop.connect(alice)["unstake(uint256)"](expandTo18Decimals(100))
    ).to.be.revertedWith("Airdrop: ended");

    // SUN supply = 1,000,000 SUN
    // Staked = 200 SUN
    // Airdrop Reward = 10 SSK
    await expect(airdropHub.connect(alice).unstake(airdrop.address))
      .to.emit(sunToken, "Transfer")
      .withArgs(airdrop.address, alice.address, expandTo18Decimals(200))
      .to.emit(airdrop, "Unstaked")
      .withArgs(alice.address, expandTo18Decimals(200))
      .to.emit(sskToken, "Transfer")
      .withArgs(airdrop.address, alice.address, expandTo18Decimals(10))
      .to.emit(airdrop, "AirdropReward")
      .withArgs(alice.address, expandTo18Decimals(10));

    expect(await sskToken.balanceOf(alice.address)).to.equal(
      expandTo18Decimals(10)
    );
    expect(await sunToken.balanceOf(alice.address)).to.equal(
      expandTo18Decimals(10000)
    );
    expect(await sskToken.balanceOf(airdrop.address)).to.equal(
      expandTo18Decimals(49990)
    );
    expect(await airdrop.currentStakerCount()).to.equal(0);
    expect(await airdrop.totalStakedAmount()).to.equal(0);

    // Cannot unstake again
    await expect(airdrop.connect(alice)["unstake()"]()).to.be.revertedWith(
      "Airdrop: zero amount"
    );
  });

  it("multiple stakers", async () => {
    await airdrop
      .connect(alice)
      ["stake(uint256,address)"](expandTo18Decimals(100), zeroAddress);
    await airdrop
      .connect(bob)
      ["stake(uint256,address)"](expandTo18Decimals(200), zeroAddress);
    await airdrop
      .connect(charlie)
      ["stake(uint256,address)"](expandTo18Decimals(300), zeroAddress);
    await airdrop
      .connect(david)
      ["stake(uint256,address)"](expandTo18Decimals(400), zeroAddress);

    expect(await airdrop.currentStakerCount()).to.equal(4);
    expect(await airdrop.totalStakedAmount()).to.equal(
      expandTo18Decimals(1000)
    );
    expect(await sunToken.balanceOf(airdrop.address)).to.equal(
      expandTo18Decimals(1000)
    );

    // Snapshot
    await mineBlock(provider, 2 * 24 * 3600);

    await expect(airdrop.connect(alice)["unstake()"]())
      .to.emit(sunToken, "Transfer")
      .withArgs(airdrop.address, alice.address, expandTo18Decimals(100))
      .to.emit(airdrop, "Unstaked")
      .withArgs(alice.address, expandTo18Decimals(100))
      .to.emit(sskToken, "Transfer")
      .withArgs(airdrop.address, alice.address, expandTo18Decimals(5))
      .to.emit(airdrop, "AirdropReward")
      .withArgs(alice.address, expandTo18Decimals(5));

    await expect(airdrop.connect(bob)["unstake()"]())
      .to.emit(sunToken, "Transfer")
      .withArgs(airdrop.address, bob.address, expandTo18Decimals(200))
      .to.emit(airdrop, "Unstaked")
      .withArgs(bob.address, expandTo18Decimals(200))
      .to.emit(sskToken, "Transfer")
      .withArgs(airdrop.address, bob.address, expandTo18Decimals(10))
      .to.emit(airdrop, "AirdropReward")
      .withArgs(bob.address, expandTo18Decimals(10));

    await expect(airdrop.connect(charlie)["unstake()"]())
      .to.emit(sunToken, "Transfer")
      .withArgs(airdrop.address, charlie.address, expandTo18Decimals(300))
      .to.emit(airdrop, "Unstaked")
      .withArgs(charlie.address, expandTo18Decimals(300))
      .to.emit(sskToken, "Transfer")
      .withArgs(airdrop.address, charlie.address, expandTo18Decimals(15))
      .to.emit(airdrop, "AirdropReward")
      .withArgs(charlie.address, expandTo18Decimals(15));

    await expect(airdrop.connect(david)["unstake()"]())
      .to.emit(sunToken, "Transfer")
      .withArgs(airdrop.address, david.address, expandTo18Decimals(400))
      .to.emit(airdrop, "Unstaked")
      .withArgs(david.address, expandTo18Decimals(400))
      .to.emit(sskToken, "Transfer")
      .withArgs(airdrop.address, david.address, expandTo18Decimals(20))
      .to.emit(airdrop, "AirdropReward")
      .withArgs(david.address, expandTo18Decimals(20));

    expect(await airdrop.currentStakerCount()).to.equal(0);
    expect(await airdrop.totalStakedAmount()).to.equal(0);
    expect(await airdrop.accuAirdropReward()).to.equal(expandTo18Decimals(50));
    expect(await sunToken.balanceOf(airdrop.address)).to.equal(0);
    expect(await sskToken.balanceOf(airdrop.address)).to.equal(
      expandTo18Decimals(49950)
    );

    expect(await sunToken.balanceOf(alice.address)).to.equal(
      expandTo18Decimals(10000)
    );
    expect(await sunToken.balanceOf(bob.address)).to.equal(
      expandTo18Decimals(10000)
    );
    expect(await sunToken.balanceOf(charlie.address)).to.equal(
      expandTo18Decimals(10000)
    );
    expect(await sunToken.balanceOf(david.address)).to.equal(
      expandTo18Decimals(10000)
    );

    expect(await sskToken.balanceOf(alice.address)).to.equal(
      expandTo18Decimals(5)
    );
    expect(await sskToken.balanceOf(bob.address)).to.equal(
      expandTo18Decimals(10)
    );
    expect(await sskToken.balanceOf(charlie.address)).to.equal(
      expandTo18Decimals(15)
    );
    expect(await sskToken.balanceOf(david.address)).to.equal(
      expandTo18Decimals(20)
    );
  });

  it("owner force unstake", async () => {
    await airdrop
      .connect(alice)
      ["stake(uint256,address)"](expandTo18Decimals(100), zeroAddress);

    // Cannot force unstake before snapshot
    await expect(
      airdrop.connect(developer).unstakeFor(alice.address)
    ).to.be.revertedWith("Airdrop: not ended");

    // Snapshot
    await mineBlock(provider, 2 * 24 * 3600);

    // Forced unstake is the same as normal unstake
    await expect(airdrop.connect(developer).unstakeFor(alice.address))
      .to.emit(sunToken, "Transfer")
      .withArgs(airdrop.address, alice.address, expandTo18Decimals(100))
      .to.emit(airdrop, "Unstaked")
      .withArgs(alice.address, expandTo18Decimals(100))
      .to.emit(sskToken, "Transfer")
      .withArgs(airdrop.address, alice.address, expandTo18Decimals(5))
      .to.emit(airdrop, "AirdropReward")
      .withArgs(alice.address, expandTo18Decimals(5));

    expect(await airdrop.currentStakerCount()).to.equal(0);
    expect(await airdrop.totalStakedAmount()).to.equal(0);
    expect(await airdrop.accuAirdropReward()).to.equal(expandTo18Decimals(5));

    expect(await sskToken.balanceOf(alice.address)).to.equal(
      expandTo18Decimals(5)
    );
    expect(await sunToken.balanceOf(alice.address)).to.equal(
      expandTo18Decimals(10000)
    );
  });

  it("referral", async () => {
    expect(await airdropHub.totalReferralCount()).to.equal(0);
    expect(await airdropHub.totalReferralReward()).to.equal(0);
    expect(await airdropHub.referrersByReferred(alice.address)).to.equal(
      zeroAddress
    );

    await expect(
      airdrop
        .connect(alice)
        ["stake(uint256,address)"](expandTo18Decimals(50), bob.address)
    )
      .to.emit(airdropHub, "Referral")
      .withArgs(bob.address, alice.address);

    expect(await airdropHub.totalReferralCount()).to.equal(1);
    expect(await airdropHub.totalReferralReward()).to.equal(0);
    expect(await airdropHub.referrersByReferred(alice.address)).to.equal(
      bob.address
    );

    // Referral relationship cannot be overwritten
    await expect(
      airdrop
        .connect(alice)
        ["stake(uint256,address)"](expandTo18Decimals(50), charlie.address)
    ).to.not.emit(airdropHub, "Referral");

    expect(await airdropHub.totalReferralCount()).to.equal(1);
    expect(await airdropHub.referrersByReferred(alice.address)).to.equal(
      bob.address
    );

    // Snapshot
    await mineBlock(provider, 2 * 24 * 3600);

    // Unstake with referral reward
    await expect(airdrop.connect(alice)["unstake()"]())
      .to.emit(sunToken, "Transfer")
      .withArgs(airdrop.address, alice.address, expandTo18Decimals(100))
      .to.emit(airdrop, "Unstaked")
      .withArgs(alice.address, expandTo18Decimals(100))
      .to.emit(sskToken, "Transfer")
      .withArgs(airdrop.address, alice.address, expandTo18Decimals(5))
      .to.emit(airdrop, "AirdropReward")
      .withArgs(alice.address, expandTo18Decimals(5))
      .to.emit(sskToken, "Transfer")
      .withArgs(airdrop.address, bob.address, expandTo18Decimals(1))
      .to.emit(airdrop, "ReferralReward")
      .withArgs(bob.address, alice.address, expandTo18Decimals(1));

    expect(await airdropHub.totalReferralReward()).to.equal(
      expandTo18Decimals(1)
    );
    expect(await airdropHub.referralRewardsByReferrer(bob.address)).to.equal(
      expandTo18Decimals(1)
    );
    expect(await airdrop.accuReferralReward()).to.equal(expandTo18Decimals(1));

    await expect(airdrop.connect(developer).burn())
      .to.emit(sskToken, "Transfer")
      .withArgs(airdrop.address, zeroAddress, expandTo18Decimals(49994));

    expect(await sskToken.balanceOf(airdrop.address)).to.equal(0);
    expect(await sskToken.balanceOf(alice.address)).to.equal(
      expandTo18Decimals(5)
    );
    expect(await sskToken.balanceOf(bob.address)).to.equal(
      expandTo18Decimals(1)
    );
  });

  it("stake all", async () => {
    expect(await sunToken.balanceOf(alice.address)).to.equal(
      expandTo18Decimals(10000)
    );

    await expect(airdrop.connect(alice)["stake(address)"](zeroAddress))
      .to.emit(sunToken, "Transfer")
      .withArgs(alice.address, airdrop.address, expandTo18Decimals(10000))
      .to.emit(airdrop, "Staked")
      .withArgs(alice.address, expandTo18Decimals(10000));

    expect(await sunToken.balanceOf(alice.address)).to.equal(0);
  });
});
