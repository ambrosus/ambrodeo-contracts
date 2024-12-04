import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";

describe("AMB Rodeo", function () {
  const totalSupply = ethers.parseEther("1000000");
  const initLiquidity = ethers.parseEther("1");
  const fee = ethers.parseEther("0.01");

  async function dep() {
    let [owner, creator, user] = await ethers.getSigners();
    const AMBRodeoDex = await ethers.getContractFactory("AMBRodeoDex");
    let dex = await upgrades.deployProxy(AMBRodeoDex, [initLiquidity, 3], {
      initializer: "initialize",
    });

    const AMBRodeoTokenFactory = await ethers.getContractFactory(
      "AMBRodeoTokenFactory"
    );
    let tokenFactory = await upgrades.deployProxy(
      AMBRodeoTokenFactory,
      [await dex.getAddress(), totalSupply, fee],
      {
        initializer: "initialize",
      }
    );

    await dex.setFactory(tokenFactory.getAddress());

    await tokenFactory
      .connect(creator)
      .deployToken("TestToken1", "TT1", "Admin1", "http://example.com/1.png", {
        value: ethers.parseEther("0.01"),
      });
    await tokenFactory
      .connect(creator)
      .deployToken("TestToken2", "TT2", "Admin2", "http://example.com/2.png", {
        value: ethers.parseEther("0.01"),
      });

    dex = await upgrades.upgradeProxy(await dex.getAddress(), AMBRodeoDex);
    tokenFactory = await upgrades.upgradeProxy(
      await tokenFactory.getAddress(),
      AMBRodeoTokenFactory
    );
    return { tokenFactory, dex, owner, creator, user };
  }

  it("Should deploy the Dex contract", async function () {
    let { dex, tokenFactory, owner, creator, user } = await loadFixture(dep);
    expect(await dex.getAddress()).to.properAddress;
  });

  it("Should deploy the TokenFactory contract", async function () {
    let { dex, tokenFactory, owner, creator, user } = await loadFixture(dep);
    expect(await tokenFactory.getAddress()).to.properAddress;
  });

  it("Should create a new Token through TokenFactory", async function () {
    let { dex, tokenFactory } = await loadFixture(dep);
    expect(await tokenFactory.tokenCount()).to.equal(2);
  });

  it("Check liquidity", async function () {
    let { dex, tokenFactory, owner, creator, user } = await loadFixture(dep);
    const tokenAddress = await tokenFactory.tokensList(0);
    const token = await ethers.getContractAt(
      "ERC20Initializable",
      tokenAddress
    );
    expect(await dex.liquidity(token.getAddress())).to.equal(initLiquidity);
  });

  it("Check token", async function () {
    let { dex, tokenFactory, owner, creator, user } = await loadFixture(dep);
    const tokenAddress = await tokenFactory.tokensList(0);
    const token = await ethers.getContractAt(
      "ERC20Initializable",
      tokenAddress
    );
    const tokenAddress2 = await tokenFactory.tokensList(1);
    const token2 = await ethers.getContractAt(
      "ERC20Initializable",
      tokenAddress2
    );

    expect(await token.name()).to.equal("TestToken1");
    expect(await token.symbol()).to.equal("TT1");
    expect(await token2.name()).to.equal("TestToken2");
    expect(await token2.symbol()).to.equal("TT2");
    expect(await token.totalSupply()).to.equal(totalSupply);
    expect(await token.balanceOf(dex.getAddress())).to.equal(totalSupply);
  });

  it("Check Buy and Sell", async function () {
    let { dex, tokenFactory, owner, creator, user } = await loadFixture(dep);
    const tokenAddress = await tokenFactory.tokensList(0);
    const token = await ethers.getContractAt(
      "ERC20Initializable",
      tokenAddress
    );

    await dex.connect(user).buy(tokenAddress, {
      value: ethers.parseEther("0.01"),
    });

    await token
      .connect(user)
      .approve(
        await dex.getAddress(),
        await token.balanceOf(user.getAddress())
      );
    await dex
      .connect(user)
      .sell(await token.getAddress(), await token.balanceOf(user.getAddress()));
    expect(await token.balanceOf(dex.getAddress())).to.equal(totalSupply);
  });

  it("Check amount out", async function () {
    let { dex, tokenFactory, owner, creator, user } = await loadFixture(dep);
    expect(await dex.swapIntoOut(500_000, 1000_000, 100)).to.equal(33);
    expect(await dex.swapIntoOut(500_000, 100, 1000_000)).to.equal(999800);
    expect(await dex.swapIntoOut(25_000, 100_000, 100_000)).to.equal(20000);
    expect(await dex.swapIntoOut(25_000, 100_000, 100_000 - 25_000)).to.equal(
      15000
    );
    expect(
      (await dex.swapIntoOut(50_000, 100_000, 100_000)) / BigInt(2)
    ).to.equal(16666);
  });
});
